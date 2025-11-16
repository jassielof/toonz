const std = @import("std");
const ztoon = @import("ztoon");

test "decode simple object" {
    const allocator = std.testing.allocator;

    const input =
        \\name: "Zig"
        \\age: 10
    ;

    var decoded = try ztoon.decode(allocator, input, .{});
    defer decoded.deinit(allocator);

    try std.testing.expect(decoded == .object);
    try std.testing.expectEqual(@as(usize, 2), decoded.object.count());

    const name = decoded.object.get("name").?;
    try std.testing.expect(name == .string);
    try std.testing.expectEqualStrings("Zig", name.string);

    const age = decoded.object.get("age").?;
    try std.testing.expect(age == .number);
    try std.testing.expectEqual(@as(f64, 10), age.number);
}

test "encode and decode round trip" {
    const allocator = std.testing.allocator;

    var obj = std.StringArrayHashMap(ztoon.Value).init(allocator);

    const name_key = try allocator.dupe(u8, "name");
    const name_str = try allocator.dupe(u8, "Zig");
    try obj.put(name_key, ztoon.Value{ .string = name_str });

    const age_key = try allocator.dupe(u8, "age");
    try obj.put(age_key, ztoon.Value{ .number = 10 });

    var value = ztoon.Value{ .object = obj };
    defer value.deinit(allocator);

    const encoded = try ztoon.encode(allocator, value, .{});
    defer allocator.free(encoded);

    var decoded = try ztoon.decode(allocator, encoded, .{});
    defer decoded.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), decoded.object.count());
}
