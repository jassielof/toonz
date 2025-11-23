const std = @import("std");

version: []const u8,
category: []const u8,
description: []const u8,
tests: []Case,

pub const Options = struct {
    delimiter: ?[]const u8 = null,
    indent: ?u64 = null,
    strict: ?bool = null,
    keyFolding: ?[]const u8 = null,
    flattenDepth: ?u64 = null,
    expandPaths: ?[]const u8 = null,
};

pub const Case = struct {
    name: []const u8,
    input: std.json.Value,
    expected: std.json.Value,
    shouldError: bool = false,
    options: ?Options = null,
    specSection: ?[]const u8 = null,
    note: ?[]const u8 = null,
    minSpecVersion: ?[]const u8 = null,
};
