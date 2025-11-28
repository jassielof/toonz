//! Stringifying/serialization errors.

/// Stringifying errors
pub const Stringifying = error{
    /// Invalid type encountered during serialization
    InvalidType,
};
