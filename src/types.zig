const std = @import("std");

/// Represents a JSON-compatible value
pub const Value = union(enum) {
    null: void,
    bool: bool,
    number: f64,
    string: []const u8,
    array: []Value,
    object: std.StringHashMap(Value),

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .array => |arr| {
                for (arr) |*item| {
                    item.deinit(allocator);
                }
                allocator.free(arr);
            },
            .object => |*obj| {
                var iter = obj.iterator();
                while (iter.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                obj.deinit();
            },
            else => {},
        }
    }
};

/// Delimiter types for TOON arrays
pub const Delimiter = enum {
    comma,
    tab,
    pipe,

    pub fn toChar(self: Delimiter) u8 {
        return switch (self) {
            .comma => ',',
            .tab => '\t',
            .pipe => '|',
        };
    }

    pub fn fromChar(c: u8) ?Delimiter {
        return switch (c) {
            ',' => .comma,
            '\t' => .tab,
            '|' => .pipe,
            else => null,
        };
    }
};

/// Options for encoding to TOON
pub const EncodeOptions = struct {
    indent: usize = 2,
    delimiter: Delimiter = .comma,
    length_marker: bool = false,
};

/// Options for decoding from TOON
pub const DecodeOptions = struct {
    indent: usize = 2,
    strict: bool = false,
};
