//! Parser context

const std = @import("std");
const Allocator = std.mem.Allocator;
const Options = @import("Options.zig");

/// Parser context structure
allocator: Allocator,

/// Parser options
options: Options,

/// Current depth of parsing
depth: usize,
