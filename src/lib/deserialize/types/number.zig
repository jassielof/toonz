const std = @import("std");

/// Parse an integer of type T from the given content.
pub fn parseInt(comptime T: type, content: []const u8) !T {
    const trimmed = std.mem.trim(u8, content, &std.ascii.whitespace);
    return std.fmt.parseInt(T, trimmed, 10) catch error.InvalidNumericLiteral;
}

/// Parse a floating-point number of type T from the given content.
pub fn parseFloat(comptime T: type, content: []const u8) !T {
    const trimmed = std.mem.trim(u8, content, &std.ascii.whitespace);
    return std.fmt.parseFloat(T, trimmed) catch error.InvalidNumericLiteral;
}
