//! Primitive encoding: strings, keys, numbers, and value joining.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Value = @import("../Value.zig").Value;
const validation = @import("validation.zig");

const LIST_ITEM_MARKER: u8 = '-';
const DEFAULT_DELIMITER: u8 = ',';
const NULL_LITERAL = "null";

/// Encodes a primitive value to a string.
pub fn encodePrimitive(value: Value, delimiter: u8, allocator: Allocator) (Allocator.Error || error{InvalidType})![]const u8 {
    return switch (value) {
        .null => try allocator.dupe(u8, NULL_LITERAL),
        .bool => |b| try allocator.dupe(u8, if (b) "true" else "false"),
        .integer => |i| blk: {
            var buf: [32]u8 = undefined;
            const str = std.fmt.bufPrint(&buf, "{d}", .{i}) catch |err| switch (err) {
                error.NoSpaceLeft => return error.OutOfMemory,
            };
            break :blk try allocator.dupe(u8, str);
        },
        .float => |f| blk: {
            // Format as canonical decimal (no exponent, no trailing zeros)
            var buf: [64]u8 = undefined;
            const str = formatCanonicalFloat(&buf, f) catch |err| switch (err) {
                error.NoSpaceLeft => return error.OutOfMemory,
            };
            break :blk try allocator.dupe(u8, str);
        },
        .number_string => |s| try allocator.dupe(u8, s),
        .string => |s| try encodeStringLiteral(s, delimiter, allocator),
        .array, .object => return error.InvalidType,
    };
}

/// Formats a float in canonical decimal form (no exponent, no trailing zeros).
fn formatCanonicalFloat(buf: []u8, f: f64) ![]const u8 {
    // Handle special cases
    if (std.math.isNan(f) or std.math.isInf(f)) {
        return try std.fmt.bufPrint(buf, "{s}", .{NULL_LITERAL});
    }
    if (f == -0.0) {
        return try std.fmt.bufPrint(buf, "0", .{});
    }

    // Format with enough precision, then remove trailing zeros
    var formatted = try std.fmt.bufPrint(buf, "{d}", .{f});

    // Remove trailing zeros after decimal point
    if (std.mem.indexOfScalar(u8, formatted, '.')) |dot_pos| {
        var end = formatted.len;
        while (end > dot_pos + 1 and formatted[end - 1] == '0') {
            end -= 1;
        }
        // If only decimal point remains, remove it
        if (end == dot_pos + 1) {
            end = dot_pos;
        }
        formatted = formatted[0..end];
    }

    return formatted;
}

/// Encodes a string literal, adding quotes if necessary.
pub fn encodeStringLiteral(value: []const u8, delimiter: u8, allocator: Allocator) Allocator.Error![]const u8 {
    if (validation.isSafeUnquoted(value, delimiter)) {
        return try allocator.dupe(u8, value);
    }

    // Need to quote and escape
    var list = std.array_list.Managed(u8).init(allocator);
    errdefer list.deinit();
    try list.append('"');
    try escapeString(value, &list);
    try list.append('"');
    return try list.toOwnedSlice();
}

/// Escapes special characters in a string.
fn escapeString(s: []const u8, writer: anytype) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writer().writeAll("\\\""),
            '\\' => try writer.writer().writeAll("\\\\"),
            '\n' => try writer.writer().writeAll("\\n"),
            '\r' => try writer.writer().writeAll("\\r"),
            '\t' => try writer.writer().writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    // Control character - should not happen in normalized strings
                    // but handle it anyway
                    try writer.writer().print("\\u{0:0>4}", .{@as(u16, c)});
                } else {
                    try writer.writer().writeByte(c);
                }
            },
        }
    }
}

/// Encodes a key, adding quotes if necessary.
pub fn encodeKey(key: []const u8, allocator: Allocator) Allocator.Error![]const u8 {
    if (validation.isValidUnquotedKey(key)) {
        return try allocator.dupe(u8, key);
    }

    // Need to quote and escape
    var list = std.array_list.Managed(u8).init(allocator);
    errdefer list.deinit();
    try list.append('"');
    try escapeString(key, &list);
    try list.append('"');
    return try list.toOwnedSlice();
}

/// Encodes and joins primitive values with a delimiter.
pub fn encodeAndJoinPrimitives(
    values: []const Value,
    delimiter: u8,
    allocator: Allocator,
) Allocator.Error![]const u8 {
    if (values.len == 0) {
        return try allocator.dupe(u8, "");
    }

    var list = std.array_list.Managed(u8).init(allocator);
    errdefer list.deinit();

    for (values, 0..) |val, i| {
        if (i > 0) {
            try list.append(delimiter);
        }
        const encoded = encodePrimitive(val, delimiter, allocator) catch |err| switch (err) {
            error.InvalidType => return error.OutOfMemory, // Should never happen for primitives
            else => |e| return e,
        };
        defer allocator.free(encoded);
        try list.writer().writeAll(encoded);
    }

    return try list.toOwnedSlice();
}

/// Formats an array header.
/// Returns a string like "key[3]:", "[3]{field1,field2}:", etc.
pub fn formatHeader(
    length: usize,
    allocator: Allocator,
    options: struct {
        key: ?[]const u8 = null,
        fields: ?[]const []const u8 = null,
        delimiter: u8 = DEFAULT_DELIMITER,
    },
) Allocator.Error![]const u8 {
    var list = std.array_list.Managed(u8).init(allocator);
    errdefer list.deinit();

    // Add key if present
    if (options.key) |key| {
        const encoded_key = try encodeKey(key, allocator);
        defer allocator.free(encoded_key);
        try list.writer().writeAll(encoded_key);
    }

    // Add bracket segment: [N] or [N<delim>]
    try list.writer().print("[{d}", .{length});
    if (options.delimiter != DEFAULT_DELIMITER) {
        try list.append(options.delimiter);
    }
    try list.append(']');

    // Add fields segment if present: {field1<delim>field2}
    if (options.fields) |fields| {
        try list.append('{');
        for (fields, 0..) |field, i| {
            if (i > 0) {
                try list.append(options.delimiter);
            }
            const encoded_field = try encodeKey(field, allocator);
            defer allocator.free(encoded_field);
            try list.writer().writeAll(encoded_field);
        }
        try list.append('}');
    }

    // Add colon
    try list.append(':');

    return try list.toOwnedSlice();
}
