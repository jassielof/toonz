const std = @import("std");
const testing = std.testing;
const toonz = @import("toonz");
// TODO: Implement similar to basic.zig, with variable schema, but using std.json.Value for data-model compatibility
const @"sample.toon" = @embedFile("data/sample.toon");
const @"sample.json" = @embedFile("data/sample.json");

test "Parsing with variable schema using Zig's std.json.Value for JSON data model compatibility" {
    
}

test "JSON compatibility for stringifying" {}
