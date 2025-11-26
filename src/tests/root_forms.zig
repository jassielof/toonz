const std = @import("std");
const testing = std.testing;
const toonz = @import("toonz");

test "Root form - empty document decodes to empty object (toonz.Value)" {
    const toon_data = "";

    const parsed = try toonz.Parse.fromSlice(toonz.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .object);
    try testing.expectEqual(@as(usize, 0), parsed.value.object.count());
}

test "Root form - empty document decodes to empty object (std.json.Value)" {
    const toon_data = "";

    const parsed = try toonz.Parse.fromSlice(std.json.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .object);
    try testing.expectEqual(@as(usize, 0), parsed.value.object.count());
}

test "Root form - single primitive string (toonz.Value)" {
    const toon_data = "hello";

    const parsed = try toonz.Parse.fromSlice(toonz.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .string);
    try testing.expectEqualStrings("hello", parsed.value.string);
}

test "Root form - single primitive string (std.json.Value)" {
    const toon_data = "hello";

    const parsed = try toonz.Parse.fromSlice(std.json.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .string);
    try testing.expectEqualStrings("hello", parsed.value.string);
}

test "Root form - single primitive integer (toonz.Value)" {
    const toon_data = "42";

    const parsed = try toonz.Parse.fromSlice(toonz.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .integer);
    try testing.expectEqual(@as(i64, 42), parsed.value.integer);
}

test "Root form - single primitive integer (std.json.Value)" {
    const toon_data = "42";

    const parsed = try toonz.Parse.fromSlice(std.json.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .integer);
    try testing.expectEqual(@as(i64, 42), parsed.value.integer);
}

test "Root form - single primitive boolean (toonz.Value)" {
    const toon_data = "true";

    const parsed = try toonz.Parse.fromSlice(toonz.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .bool);
    try testing.expectEqual(true, parsed.value.bool);
}

test "Root form - single primitive boolean (std.json.Value)" {
    const toon_data = "true";

    const parsed = try toonz.Parse.fromSlice(std.json.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .bool);
    try testing.expectEqual(true, parsed.value.bool);
}

test "Root form - single primitive null (toonz.Value)" {
    const toon_data = "null";

    const parsed = try toonz.Parse.fromSlice(toonz.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .null);
}

test "Root form - single primitive null (std.json.Value)" {
    const toon_data = "null";

    const parsed = try toonz.Parse.fromSlice(std.json.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .null);
}

test "Root form - object (not single primitive) (toonz.Value)" {
    const toon_data =
        \\name: Alice
        \\age: 30
    ;

    const parsed = try toonz.Parse.fromSlice(toonz.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .object);
    try testing.expectEqual(@as(usize, 2), parsed.value.object.count());
}

test "Root form - object (not single primitive) (std.json.Value)" {
    const toon_data =
        \\name: Alice
        \\age: 30
    ;

    const parsed = try toonz.Parse.fromSlice(std.json.Value, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value == .object);
    try testing.expectEqual(@as(usize, 2), parsed.value.object.count());
}
