const std = @import("std");

/// Check if a numeric token has invalid leading zeros per spec §4
/// Returns true if the token is invalid (should be treated as string)
fn hasInvalidLeadingZero(token: []const u8) bool {
    if (token.len == 0) return false;
    if (token.len == 1) return false; // "0" is valid

    // Check for leading zero
    if (token[0] == '0') {
        // "-0" is valid (will be normalized to 0)
        if (token.len >= 2) {
            const next_char = token[1];
            // "0.5" is valid (decimal), "0e6" is valid (exponent)
            if (next_char != '.' and next_char != 'e' and next_char != 'E') {
                return true; // Invalid: "05", "00", "0123", etc.
            }
        }
    }

    // Check for negative with leading zero: "-05" is invalid
    if (token.len >= 3 and token[0] == '-' and token[1] == '0') {
        const next_char = token[2];
        if (next_char != '.' and next_char != 'e' and next_char != 'E') {
            return true; // Invalid: "-05", "-00", "-0123", etc.
        }
    }

    return false;
}

/// Check if a token looks like a number (for validation, not parsing)
pub fn isNumericLiteral(token: []const u8) bool {
    if (token.len == 0) return false;

    // Reject invalid leading zeros
    if (hasInvalidLeadingZero(token)) return false;

    // Try to parse as float (handles int, float, and exponent notation)
    const result = std.fmt.parseFloat(f64, token) catch return false;

    // Must be finite
    return std.math.isFinite(result);
}

/// Parse an integer of type T from the given content.
/// Per spec §4: Rejects tokens with forbidden leading zeros as numbers.
pub fn parseInt(comptime T: type, content: []const u8) !T {
    const trimmed = std.mem.trim(u8, content, &std.ascii.whitespace);

    // Check for invalid leading zeros per spec §4
    if (hasInvalidLeadingZero(trimmed)) {
        return error.InvalidNumericLiteral;
    }

    const result = std.fmt.parseInt(T, trimmed, 10) catch return error.InvalidNumericLiteral;

    // Normalize -0 to 0 per spec §2
    if (result == 0) return 0;

    return result;
}

/// Parse a floating-point number of type T from the given content.
/// Per spec §4: Accepts decimal and exponent forms (e.g., 42, -3.14, 1e-6, -1E+9).
/// Rejects tokens with forbidden leading zeros.
pub fn parseFloat(comptime T: type, content: []const u8) !T {
    const trimmed = std.mem.trim(u8, content, &std.ascii.whitespace);

    // Check for invalid leading zeros per spec §4
    if (hasInvalidLeadingZero(trimmed)) {
        return error.InvalidNumericLiteral;
    }

    // std.fmt.parseFloat already handles exponent notation
    const result = std.fmt.parseFloat(T, trimmed) catch return error.InvalidNumericLiteral;

    // Normalize -0 to 0 per spec §2
    // Most Zig environments don't distinguish -0 from 0, but check anyway
    if (result == 0.0) return 0.0;

    return result;
}
