const std = @import("std");
const ztoon = @import("ztoon");
const types = @import("types.zig");
const testing = std.testing;

const fixtures_path = "spec/tests/fixtures/decode/";
const fixtures = [_][]const u8{
    "primitives.json",
    "numbers.json",
    "objects.json",
    "arrays-primitive.json",
    "arrays-tabular.json",
    "arrays-nested.json",
    "path-expansion.json",
    "delimiters.json",
    "whitespace.json",
    "root-form.json",
    "validation-errors.json",
    "indentation-errors.json",
    "blank-lines.json",
};

test "decode all fixtures" {
    inline for (fixtures) |fixture| {
        std.debug.print("Testing {s}\n", .{fixture});

        const full_path = try std.fs.path.join(
            testing.allocator,
            &.{ fixtures_path, fixture },
        );
        defer testing.allocator.free(full_path);

        const file_content = try std.fs.cwd().readFileAlloc(
            testing.allocator,
            full_path,
            1024 * 1024,
        );
        defer testing.allocator.free(file_content);

        std.debug.print("Read {d} bytes from {s}\n", .{ file_content.len, fixture });
    }
}
