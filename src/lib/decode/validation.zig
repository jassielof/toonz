const std = @import("std");
const types = @import("../types.zig");
const errors = @import("../errors.zig");
const constants = @import("../constants.zig");
const scanner = @import("scanner.zig");

const ArrayHeaderInfo = types.ArrayHeaderInfo;
const BlankLineInfo = types.BlankLineInfo;
const Depth = types.Depth;
const Delimiter = constants.Delimiter;
const LineCursor = scanner.LineCursor;
const ResolvedDecodingOptions = types.ResolvedDecodingOptions;

const LIST_ITEM_PREFIX = constants.list_item_prefix;
const COLON = constants.colon;

/// Asserts that the actual count matches the expected count in strict mode
pub fn assertExpectedCount(
    actual: u64,
    expected: u64,
    item_type: []const u8,
    options: ResolvedDecodingOptions,
) !void {
    _ = item_type; // Suppress unused parameter warning
    if (options.strict and actual != expected) {
        // In Zig, we can't format strings in error messages directly,
        // so we return a generic error
        return errors.DecodeError.CountMismatch;
    }
}

/// Validates that there are no extra list items beyond the expected count
pub fn validateNoExtraListItems(
    cursor: *const LineCursor,
    item_depth: Depth,
    expected_count: u64,
) !void {
    _ = expected_count; // Suppress unused parameter warning
    const next_line = cursor.peek() orelse return;

    if (next_line.depth == item_depth and
        std.mem.startsWith(u8, next_line.content, LIST_ITEM_PREFIX))
    {
        return errors.DecodeError.TooManyItems;
    }
}

/// Validates that there are no extra tabular rows beyond the expected count
pub fn validateNoExtraTabularRows(
    cursor: *const LineCursor,
    row_depth: Depth,
    header: ArrayHeaderInfo,
) !void {
    const next_line = cursor.peek() orelse return;

    if (next_line.depth == row_depth and
        !std.mem.startsWith(u8, next_line.content, LIST_ITEM_PREFIX) and
        isDataRow(next_line.content, header.delimiter))
    {
        return errors.DecodeError.TooManyItems;
    }
}

/// Validates that there are no blank lines within a specific line range in strict mode
pub fn validateNoBlankLinesInRange(
    start_line: u64,
    end_line: u64,
    blank_lines: []const BlankLineInfo,
    strict: bool,
    context: []const u8,
) !void {
    if (!strict) return;

    // Find blank lines within the range
    for (blank_lines) |blank| {
        if (blank.line_number > start_line and blank.line_number < end_line) {
            _ = context; // Suppress unused parameter warning
            return errors.DecodeError.BlankLinesNotAllowed;
        }
    }
}

/// Checks if a line is a data row (vs a key-value pair) in a tabular array
fn isDataRow(content: []const u8, delimiter: Delimiter) bool {
    const colon_pos = std.mem.indexOfScalar(u8, content, COLON);
    const delimiter_pos = std.mem.indexOfScalar(u8, content, delimiter);

    // No colon = definitely a data row
    if (colon_pos == null) {
        return true;
    }

    // Has delimiter and it comes before colon = data row
    if (delimiter_pos != null and delimiter_pos.? < colon_pos.?) {
        return true;
    }

    // Colon before delimiter or no delimiter = key-value pair
    return false;
}

// #region Validation utilities for identifiers and literals

/// Checks if a key can be used without quotes
pub fn isValidUnquotedKey(key: []const u8) bool {
    if (key.len == 0) return false;

    // Must start with letter or underscore
    const first = key[0];
    if (!std.ascii.isAlphabetic(first) and first != '_') return false;

    // Rest can be letters, digits, underscores, or dots
    for (key[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '.') {
            return false;
        }
    }

    return true;
}

/// Checks if a key segment is a valid identifier for safe folding/expansion
pub fn isIdentifierSegment(key: []const u8) bool {
    if (key.len == 0) return false;

    // Must start with letter or underscore
    const first = key[0];
    if (!std.ascii.isAlphabetic(first) and first != '_') return false;

    // Rest can be letters, digits, or underscores (NO dots)
    for (key[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') {
            return false;
        }
    }

    return true;
}

/// Checks if a token represents a boolean or null literal
pub fn isBooleanOrNullLiteral(token: []const u8) bool {
    return std.mem.eql(u8, token, constants.true_literal) or
        std.mem.eql(u8, token, constants.false_literal) or
        std.mem.eql(u8, token, constants.null_literal);
}

/// Checks if a token represents a valid numeric literal
pub fn isNumericLiteral(token: []const u8) bool {
    if (token.len == 0) return false;

    // Must not have leading zeros (except for "0" itself or decimals like "0.5")
    if (token.len > 1 and token[0] == '0' and token[1] != '.') {
        return false;
    }

    // Try to parse as float
    const value = std.fmt.parseFloat(f64, token) catch return false;

    // Check if it's finite
    return !std.math.isNan(value) and !std.math.isInf(value);
}

// #endregion
