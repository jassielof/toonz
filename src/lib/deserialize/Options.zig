//! Options for parsing TOON

/// Number of spaces to use for indentation.
/// Defaults to 2 if not specified (per spec §13).
indent: ?usize = null,

/// Whether to enforce strict validation for array lengths and tabular row counts.
strict: ?bool = true,

/// Whether to enable path expansion to reconstruct dotted keys into nested objects.
///
/// When set to safe, keys containing dots are expanded into nested structures if all segments are valid identifiers, for example: `data.metadata.items` turns into nested objects.
///
/// It pairs with key folding set to safe for lossless round-trips.
expand_paths: enum { off, safe } = .off,

/// Maximum parsing depth to prevent stack overflow from malicious input, which is a safety measure not present in the specification and main implementation (made in TS which relies on JS's native stack limits).
/// Defaults to 256 levels of nesting.
max_depth: usize = 256,
