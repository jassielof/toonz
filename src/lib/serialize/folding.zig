//! Key folding logic for collapsing single-key object chains.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Value = @import("../Value.zig").Value;
const normalize = @import("normalize.zig");
const validation = @import("validation.zig");

const DOT: u8 = '.';

/// Result of attempting to fold a key chain.
pub const FoldResult = struct {
    /// The folded key with dot-separated segments (e.g., "data.metadata.items")
    folded_key: []const u8,
    /// The remainder value after folding:
    /// - `null` if the chain was fully folded to a leaf (primitive, array, or empty object)
    /// - An object if the chain was partially folded (depth limit reached with nested tail)
    remainder: ?Value,
    /// The leaf value at the end of the folded chain.
    leaf_value: Value,
    /// The number of segments that were folded.
    segment_count: usize,
};

/// Attempts to fold a single-key object chain into a dotted path.
/// Returns null if folding is not possible or safe.
pub fn tryFoldKeyChain(
    key: []const u8,
    value: Value,
    siblings: []const []const u8,
    options: struct {
        key_folding: enum { off, safe },
        flatten_depth: ?usize,
    },
    root_literal_keys: ?std.StringHashMap(void),
    path_prefix: ?[]const u8,
    flatten_depth_override: ?usize,
    allocator: Allocator,
) Allocator.Error!?FoldResult {
    // Only fold when safe mode is enabled
    if (options.key_folding != .safe) {
        return null;
    }

    // Can only fold objects
    if (value != .object) {
        return null;
    }

    // Use provided flattenDepth or fall back to options default
    const effective_flatten_depth = flatten_depth_override orelse options.flatten_depth orelse std.math.maxInt(usize);

    // Collect the chain of single-key objects
    const chain_result = try collectSingleKeyChain(key, value, effective_flatten_depth, allocator);
    errdefer {
        if (chain_result.leaf_value != .object) {
            chain_result.leaf_value.deinit(allocator);
        }
        if (chain_result.tail) |tail| {
            tail.deinit(allocator);
        }
    }

    // Need at least 2 segments for folding to be worthwhile
    if (chain_result.segments.items.len < 2) {
        chain_result.segments.deinit();
        return null;
    }

    // Validate all segments are safe identifiers
    for (chain_result.segments.items) |seg| {
        if (!validation.isIdentifierSegment(seg)) {
            chain_result.segments.deinit();
            return null;
        }
    }

    // Build the folded key (relative to current nesting level)
    const folded_key = try buildFoldedKey(chain_result.segments.items, allocator);
    errdefer allocator.free(folded_key);

    // Build the absolute path from root
    const absolute_path = if (path_prefix) |prefix|
        try std.fmt.allocPrint(allocator, "{s}.{s}", .{ prefix, folded_key })
    else
        try allocator.dupe(u8, folded_key);
    errdefer allocator.free(absolute_path);

    // Check for collision with existing literal sibling keys (at current level)
    for (siblings) |sibling| {
        if (std.mem.eql(u8, sibling, folded_key)) {
            chain_result.segments.deinit();
            allocator.free(absolute_path);
            return null;
        }
    }

    // Check for collision with root-level literal dotted keys
    if (root_literal_keys) |literal_keys| {
        if (literal_keys.contains(absolute_path)) {
            chain_result.segments.deinit();
            allocator.free(absolute_path);
            return null;
        }
    }

    allocator.free(absolute_path);

    return FoldResult{
        .folded_key = folded_key,
        .remainder = chain_result.tail,
        .leaf_value = chain_result.leaf_value,
        .segment_count = chain_result.segments.items.len,
    };
}

/// Collects a chain of single-key objects into segments.
const ChainResult = struct {
    segments: std.array_list.Managed([]const u8),
    tail: ?Value,
    leaf_value: Value,
};

fn collectSingleKeyChain(
    start_key: []const u8,
    start_value: Value,
    max_depth: usize,
    allocator: Allocator,
) Allocator.Error!ChainResult {
    var segments = std.array_list.Managed([]const u8).init(allocator);
    errdefer segments.deinit();
    try segments.append(try allocator.dupe(u8, start_key));

    var current_value = start_value;

    // Traverse nested single-key objects, collecting each key into segments array
    // Stop when we encounter: multi-key object, array, primitive, or depth limit
    while (segments.items.len < max_depth) {
        // Must be an object to continue
        if (current_value != .object) {
            break;
        }

        const obj = current_value.object;

        // Must have exactly one key to continue the chain
        if (obj.count() != 1) {
            break;
        }

        var it = obj.iterator();
        const entry = it.next().?;
        const next_key = entry.key_ptr.*;
        const next_value = entry.value_ptr.*;

        try segments.append(try allocator.dupe(u8, next_key));
        current_value = next_value;
    }

    // Determine the tail
    if (current_value != .object or normalize.isEmptyObject(current_value.object)) {
        // Array, primitive, null, or empty object - this is a leaf value
        return ChainResult{
            .segments = segments,
            .tail = null,
            .leaf_value = current_value,
        };
    }

    // Has keys - return as tail (remainder)
    // Clone the object for the tail
    const tail_clone = try current_value.clone(allocator);
    return ChainResult{
        .segments = segments,
        .tail = tail_clone,
        .leaf_value = tail_clone,
    };
}

fn buildFoldedKey(segments: []const []const u8, allocator: Allocator) Allocator.Error![]const u8 {
    if (segments.len == 0) {
        return try allocator.dupe(u8, "");
    }
    if (segments.len == 1) {
        return try allocator.dupe(u8, segments[0]);
    }

    var list = std.array_list.Managed(u8).init(allocator);
    errdefer list.deinit();

    for (segments, 0..) |seg, i| {
        if (i > 0) {
            try list.append(DOT);
        }
        try list.writer().writeAll(seg);
    }

    return try list.toOwnedSlice();
}
