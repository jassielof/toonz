//! Validation utilities for keys and strings.

const std = @import("std");

/// Checks if a key can be used without quotes.
/// Valid unquoted keys must start with a letter or underscore,
/// followed by letters, digits, underscores, or dots.
pub fn isValidUnquotedKey(key: []const u8) bool {
    if (key.len == 0) return false;
    const first = key[0];
    if (!std.ascii.isAlphabetic(first) and first != '_') return false;
    for (key[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '.') {
            return false;
        }
    }
    return true;
}

/// Checks if a key segment is a valid identifier for safe folding/expansion.
/// Identifier segments are more restrictive than unquoted keys:
/// - Must start with a letter or underscore
/// - Followed only by letters, digits, or underscores (no dots)
pub fn isIdentifierSegment(key: []const u8) bool {
    if (key.len == 0) return false;
    const first = key[0];
    if (!std.ascii.isAlphabetic(first) and first != '_') return false;
    for (key[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') {
            return false;
        }
    }
    return true;
}

/// Checks if a string looks like a boolean or null literal.
fn isBooleanOrNullLiteral(value: []const u8) bool {
    return std.mem.eql(u8, value, "true") or
        std.mem.eql(u8, value, "false") or
        std.mem.eql(u8, value, "null");
}

/// Checks if a string looks like a number.
fn isNumericLike(value: []const u8) bool {
    if (value.len == 0) return false;
    var i: usize = 0;
    if (value[0] == '-') {
        if (value.len == 1) return false;
        i += 1;
    }
    var has_digit = false;
    var has_dot = false;
    while (i < value.len) : (i += 1) {
        const c = value[i];
        if (std.ascii.isDigit(c)) {
            has_digit = true;
        } else if (c == '.' and !has_dot) {
            has_dot = true;
        } else if (c == 'e' or c == 'E') {
            // Scientific notation - needs quoting
            return true;
        } else {
            // Not a number
            break;
        }
    }
    // Check for leading zeros (forbidden in numbers)
    if (value.len > 1 and value[0] == '0' and std.ascii.isDigit(value[1])) {
        return true; // Leading zero - needs quoting
    }
    return has_digit and i == value.len;
}

/// Determines if a string value can be safely encoded without quotes.
/// A string needs quoting if it:
/// - Is empty
/// - Has leading or trailing whitespace
/// - Could be confused with a literal (boolean, null, number)
/// - Contains structural characters (colons, brackets, braces)
/// - Contains quotes or backslashes (need escaping)
/// - Contains control characters (newlines, tabs, etc.)
/// - Contains the active delimiter
/// - Starts with a list marker (hyphen)
pub fn isSafeUnquoted(value: []const u8, delimiter: u8) bool {
    if (value.len == 0) return false;

    // Check for leading/trailing whitespace
    if (value[0] == ' ' or value[value.len - 1] == ' ') return false;
    if (std.mem.indexOfAny(u8, value, "\t\n\r") != null) return false;

    // Check if it looks like a literal
    if (isBooleanOrNullLiteral(value) or isNumericLike(value)) return false;

    // Check for structural characters
    if (std.mem.indexOfAny(u8, value, ":[]{}") != null) return false;

    // Check for quotes and backslash
    if (std.mem.indexOfAny(u8, value, "\"\\") != null) return false;

    // Check for control characters
    for (value) |c| {
        if (c < 0x20) return false;
    }

    // Check for the active delimiter
    if (std.mem.indexOfScalar(u8, value, delimiter) != null) return false;

    // Check for hyphen at start (list marker)
    if (value.len > 0 and value[0] == '-') return false;

    return true;
}
