const std = @import("std");
const testing = std.testing;
const toonz = @import("toonz");

test "Delimiter support - comma (default)" {
    const toon_data =
        \\tags[3]: reading,gaming,coding
    ;

    const T = struct {
        tags: []const []const u8,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(3, parsed.value.tags.len);
    try testing.expectEqualStrings("reading", parsed.value.tags[0]);
    try testing.expectEqualStrings("gaming", parsed.value.tags[1]);
    try testing.expectEqualStrings("coding", parsed.value.tags[2]);
}

test "Delimiter support - tab delimiter" {
    const toon_data = "tags[3\t]: reading\tgaming\tcoding\n";

    const T = struct {
        tags: []const []const u8,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(3, parsed.value.tags.len);
    try testing.expectEqualStrings("reading", parsed.value.tags[0]);
    try testing.expectEqualStrings("gaming", parsed.value.tags[1]);
    try testing.expectEqualStrings("coding", parsed.value.tags[2]);
}

test "Delimiter support - pipe delimiter" {
    const toon_data =
        \\tags[3|]: reading|gaming|coding
    ;

    const T = struct {
        tags: []const []const u8,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(3, parsed.value.tags.len);
    try testing.expectEqualStrings("reading", parsed.value.tags[0]);
    try testing.expectEqualStrings("gaming", parsed.value.tags[1]);
    try testing.expectEqualStrings("coding", parsed.value.tags[2]);
}

test "Delimiter support - tabular with tab delimiter" {
    const toon_data = "items[2\t]{id\tname}:\n  1\tAlice\n  2\tBob\n";

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

test "Delimiter support - tabular with pipe delimiter" {
    const toon_data =
        \\items[2|]{id|name}:
        \\  1|Alice
        \\  2|Bob
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

test "Delimiter support - numbers with different delimiters" {
    const toon_data_comma =
        \\nums[3]: 1,2,3
    ;
    const toon_data_tab = "nums[3\t]: 1\t2\t3\n";
    const toon_data_pipe =
        \\nums[3|]: 1|2|3
    ;

    const T = struct {
        nums: []const u64,
    };

    // Test comma
    {
        const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data_comma, .{});
        defer parsed.deinit();
        try testing.expectEqual(3, parsed.value.nums.len);
        try testing.expectEqual(1, parsed.value.nums[0]);
        try testing.expectEqual(2, parsed.value.nums[1]);
        try testing.expectEqual(3, parsed.value.nums[2]);
    }

    // Test tab
    {
        const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data_tab, .{});
        defer parsed.deinit();
        try testing.expectEqual(3, parsed.value.nums.len);
        try testing.expectEqual(1, parsed.value.nums[0]);
        try testing.expectEqual(2, parsed.value.nums[1]);
        try testing.expectEqual(3, parsed.value.nums[2]);
    }

    // Test pipe
    {
        const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data_pipe, .{});
        defer parsed.deinit();
        try testing.expectEqual(3, parsed.value.nums.len);
        try testing.expectEqual(1, parsed.value.nums[0]);
        try testing.expectEqual(2, parsed.value.nums[1]);
        try testing.expectEqual(3, parsed.value.nums[2]);
    }
}

test "Delimiter support - mixed content with pipe (contains commas in data)" {
    const toon_data =
        \\tags[3|]: "a,b"|"c,d"|"e,f"
    ;

    const T = struct {
        tags: []const []const u8,
    };

    const parsed = try toonz.Parse.fromSlice(T, testing.allocator, toon_data, .{});
    defer parsed.deinit();

    try testing.expectEqual(3, parsed.value.tags.len);
    try testing.expectEqualStrings("a,b", parsed.value.tags[0]);
    try testing.expectEqualStrings("c,d", parsed.value.tags[1]);
    try testing.expectEqualStrings("e,f", parsed.value.tags[2]);
}
