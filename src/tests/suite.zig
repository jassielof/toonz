const std = @import("std");
const testing = std.testing;

const toonz = @import("toonz");

comptime {
    _ = @import("basic.zig");
    _ = @import("json.zig");
    _ = @import("delimiters.zig");
    _ = @import("root_forms.zig");
    _ = @import("expanded_arrays.zig");
    _ = @import("spec/parse.zig");
    // _ = @import("spec/stringify.zig");
}

test {
    testing.refAllDecls(@This());
}
