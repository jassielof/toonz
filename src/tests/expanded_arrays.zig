const std = @import("std");
const testing = std.testing;
const toonz = @import("toonz");

test "Expanded arrays - primitive list items" {
    const toon_data =
        \\items[3]:
        \\  - first
        \\  - second
        \\  - third
    ;

    const T = struct {
        items: []const []const u8,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(3, parsed.value.items.len);
    try testing.expectEqualStrings("first", parsed.value.items[0]);
    try testing.expectEqualStrings("second", parsed.value.items[1]);
    try testing.expectEqualStrings("third", parsed.value.items[2]);
}

test "Expanded arrays - arrays of arrays with primitives" {
    const toon_data =
        \\pairs[2]:
        \\  - [2]: a,b
        \\  - [2]: c,d
    ;

    const T = struct {
        pairs: []const []const []const u8,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(2, parsed.value.pairs.len);
    try testing.expectEqual(2, parsed.value.pairs[0].len);
    try testing.expectEqualStrings("a", parsed.value.pairs[0][0]);
    try testing.expectEqualStrings("b", parsed.value.pairs[0][1]);
    try testing.expectEqual(2, parsed.value.pairs[1].len);
    try testing.expectEqualStrings("c", parsed.value.pairs[1][0]);
    try testing.expectEqualStrings("d", parsed.value.pairs[1][1]);
}

test "Expanded arrays - objects with first field on hyphen line" {
    const toon_data =
        \\items[2]:
        \\  - id: 1
        \\    name: Alice
        \\  - id: 2
        \\    name: Bob
    ;

    const T = struct {
        items: []const struct {
            id: u64,
            name: []const u8,
        },
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(2, parsed.value.items.len);
    try testing.expectEqual(1, parsed.value.items[0].id);
    try testing.expectEqualStrings("Alice", parsed.value.items[0].name);
    try testing.expectEqual(2, parsed.value.items[1].id);
    try testing.expectEqualStrings("Bob", parsed.value.items[1].name);
}

test "Expanded arrays - arrays of numbers" {
    const toon_data =
        \\pairs[2]:
        \\  - [2]: 1,2
        \\  - [2]: 3,4
    ;

    const T = struct {
        pairs: []const []const u64,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(2, parsed.value.pairs.len);
    try testing.expectEqual(@as(usize, 2), parsed.value.pairs[0].len);
    try testing.expectEqual(@as(u64, 1), parsed.value.pairs[0][0]);
    try testing.expectEqual(@as(u64, 2), parsed.value.pairs[0][1]);
    try testing.expectEqual(@as(usize, 2), parsed.value.pairs[1].len);
    try testing.expectEqual(@as(u64, 3), parsed.value.pairs[1][0]);
    try testing.expectEqual(@as(u64, 4), parsed.value.pairs[1][1]);
}

test "Expanded arrays - with tab delimiter" {
    const toon_data = "pairs[2\t]:\n  - [2\t]: a\tb\n  - [2\t]: c\td\n";

    const T = struct {
        pairs: []const []const []const u8,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(2, parsed.value.pairs.len);
    try testing.expectEqual(2, parsed.value.pairs[0].len);
    try testing.expectEqualStrings("a", parsed.value.pairs[0][0]);
    try testing.expectEqualStrings("b", parsed.value.pairs[0][1]);
}

test "Expanded arrays - with pipe delimiter" {
    const toon_data =
        \\pairs[2|]:
        \\  - [2|]: a|b
        \\  - [2|]: c|d
    ;

    const T = struct {
        pairs: []const []const []const u8,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(2, parsed.value.pairs.len);
    try testing.expectEqual(2, parsed.value.pairs[0].len);
    try testing.expectEqualStrings("a", parsed.value.pairs[0][0]);
    try testing.expectEqualStrings("b", parsed.value.pairs[0][1]);
}

test "Expanded arrays - empty inner arrays" {
    const toon_data =
        \\pairs[2]:
        \\  - [0]:
        \\  - [0]:
    ;

    const T = struct {
        pairs: []const []const []const u8,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(2, parsed.value.pairs.len);
    try testing.expectEqual(0, parsed.value.pairs[0].len);
    try testing.expectEqual(0, parsed.value.pairs[1].len);
}

test "Expanded arrays - mixed length inner arrays" {
    const toon_data =
        \\pairs[2]:
        \\  - [1]: 1
        \\  - [2]: 2,3
    ;

    const T = struct {
        pairs: []const []const u64,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(2, parsed.value.pairs.len);
    try testing.expectEqual(@as(usize, 1), parsed.value.pairs[0].len);
    try testing.expectEqual(@as(u64, 1), parsed.value.pairs[0][0]);
    try testing.expectEqual(@as(usize, 2), parsed.value.pairs[1].len);
    try testing.expectEqual(@as(u64, 2), parsed.value.pairs[1][0]);
    try testing.expectEqual(@as(u64, 3), parsed.value.pairs[1][1]);
}
