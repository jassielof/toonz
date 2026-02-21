//! Fixture definition for TOON specification tests.

const std = @import("std");

/// The TOON specification version the test fixtures conform to.
version: []const u8,

/// Test category, either "decode" or "encode".
category: []const u8,

/// Brief description of the fixture.
description: []const u8,

/// Array of test cases.
tests: []Case,

/// A single test case within a fixture.
pub const Case = struct {
    /// The case name which explains what's being validated.
    name: []const u8,
    /// The input value:
    /// - For deserialization: a TOON string
    /// - For serialization: an object
    input: std.json.Value,
    /// The expected output value:
    /// - For deserialization: an object
    /// - For serialization: a TOON string
    expected: std.json.Value,
    /// Whether the test case is expected to fail.
    shouldError: bool = false,
    /// De/serialization options to use for this test case.
    options: ?Options = null,
    /// The specification reference section related to this test case.
    specSection: ?[]const u8 = null,
    /// Optional notes for special or edge case/s behavior.
    note: ?[]const u8 = null,
    /// The minimum TOON specification version required for this test case.
    minSpecVersion: ?[]const u8 = null,

    /// Options for de/serialization.
    pub const Options = struct {
        /// The delimiter to use for arrays (only for serializing)
        delimiter: ?[]const u8 = null,
        /// The number of spaces per indentation level.
        indent: ?u64 = null,
        /// Whether to enable strict validation (only for deserialization)
        strict: ?bool = null,
        /// The key folding strategy for serialization (v1.5+):
        /// - off by default
        /// - safe (only for serialization)
        keyFolding: ?[]const u8 = null,
        /// The maximum depth to fold key chains when key folding is set as safe.
        ///
        /// Serialization only: Values with less than 2 have no practical folding effect.
        flattenDepth: ?u64 = null,
        /// The path expansion strategy for deserialization:
        /// - off by default
        /// - safe (only for deserialization)
        expandPaths: ?[]const u8 = null,
    };
};

/// Loads all JSON files from a directory into a StringHashMap and the caller own the returned map and must deinitialize it when done.
///
/// It uses the provided allocator for all allocations.
pub fn loadFromDir(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
) !std.StringHashMap(std.json.Value) {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var fixtures = std.StringHashMap(std.json.Value).init(allocator);
    errdefer fixtures.deinit();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".json")) continue;

        const content = try dir.readFileAlloc(allocator, entry.name, 10 * 1024 * 1024);
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
        try fixtures.put(entry.name, parsed.value);
    }

    return fixtures;
}
