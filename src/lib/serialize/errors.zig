const std = @import("std");

const ParseError = @import("../parse/errors.zig").ParseError;
const ScanError = @import("../scan/errors.zig").ScanError;

/// Stringifying errors
pub const Stringifying = error{
    /// No content to decode
    NoContentToDecode,
    /// Expected count doesn't match actual (strict mode)
    CountMismatch,
    /// More items found than expected
    TooManyItems,
    /// Blank lines not allowed in certain contexts (strict mode)
    BlankLinesNotAllowed,
    /// Type mismatch during path expansion
    PathExpansionConflict,
} || ParseError || ScanError;
