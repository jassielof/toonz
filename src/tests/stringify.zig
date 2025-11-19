const std = @import("std");
const testing = std.testing;
const utils = @import("utils.zig");

test "stringify fixtures" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const fixtures = try utils.loadJsonFixtures(allocator, "src/tests/spec/tests/fixtures/encode/");

    var fxt_it = fixtures.iterator();
    while (fxt_it.next()) |entry| {
        std.debug.print("Stringify test - {s}: {f}\n", .{
            entry.key_ptr.*,
            std.json.fmt(entry.value_ptr.*, .{}),
        });

        // Your parse testing logic here
        // const result = try yourParser.parse(entry.value_ptr.*);
        // try testing.expect(result.isValid());
    }
}
