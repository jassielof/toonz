//! Options for stringifying TOON

/// The number of spaces to use for indentation.
indent: u64 = 2,

/// The delimiter to use for tabular array rows and inline primitive arrays.
delimiter: ?u8 = ',',

/// Whether to enable key folding to collapse single-key wrapper chains.
///
/// When set to safe, nested objects with single keys are collapsed into dotted paths (e.g., data.metadata.items instead of nested indentation).
key_folding: enum { off, safe } = .off,

/// This controls how deep the folding can go in single-key chains and the maximum number of segments to fold when key folding is enabled.
///
/// The values 0 or 1 have no practical effect, they are treated as effectively disabled.
///
/// When set to null, there is no limit to folding depth.
flatten_depth: ?u64 = null,
