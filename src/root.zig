const std = @import("std");

pub const types = @import("types.zig");
pub const encoder = @import("encoder.zig");
pub const decoder = @import("decoder.zig");

// Re-export commonly used types
pub const Value = types.Value;
pub const Delimiter = types.Delimiter;
pub const EncodeOptions = types.EncodeOptions;
pub const DecodeOptions = types.DecodeOptions;

// Re-export main functions
pub const encode = encoder.encode;
pub const decode = decoder.decode;

test {
    std.testing.refAllDecls(@This());
}
