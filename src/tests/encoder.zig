const std = @import("std");

test "always true in encoder" {
    try std.testing.expect(true);
}
