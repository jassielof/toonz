const std = @import("std");
const FromValueError = @import("../errors.zig").FromValueError;

/// Parse a boolean value from a given content.
pub fn parseBool(content: []const u8) FromValueError!bool {
    const trimmed = std.mem.trim(u8, content, &std.ascii.whitespace);
    if (std.mem.eql(u8, trimmed, "true")) return true;
    if (std.mem.eql(u8, trimmed, "false")) return false;

    return error.InvalidBooleanLiteral;
}
