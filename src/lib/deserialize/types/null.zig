const std = @import("std");

/// Check if the content represents a null value.
pub fn isNull(content: []const u8) bool {
    const trimmed = std.mem.trim(u8, content, &std.ascii.whitespace);
    return std.mem.eql(u8, trimmed, "null");
}
