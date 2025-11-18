const std = @import("std");

pub const TestCase = struct {
    name: []const u8,
    input: std.json.Value,
    expected: std.json.Value,
    should_error: bool = false,
    options: ?struct { delimiter: ?enum { comma, tab, pipe }, indent: ?u64, strict: ?bool, key_folding: ?enum { off, safe }, flatten_depth: ?u64, expand_paths: ?enum { off, safe } },
    spec_section: ?[]const u8,
    note: ?[]const u8,
    min_spec_version: ?[]const u8,
};

pub const Fixtures = struct {
    version: []const u8,
    category: enum { encode, decode },
    description: []const u8,
    tests: []const TestCase,
};
