//! Normalization of values to the JSON data model before encoding.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Value = @import("../Value.zig").Value;

/// Normalizes a std.json.Value to our Value type.
/// This handles the conversion from JSON's representation to TOON's representation.
pub fn normalizeJsonValue(allocator: Allocator, json_value: std.json.Value) Allocator.Error!Value {
    return switch (json_value) {
        .null => .null,
        .bool => |b| .{ .bool = b },
        .integer => |i| .{ .integer = i },
        .float => |f| blk: {
            // Normalize -0 to 0
            if (f == -0.0) {
                break :blk .{ .integer = 0 };
            }
            // Check for NaN and Infinity
            if (std.math.isNan(f) or std.math.isInf(f)) {
                break :blk .null;
            }
            break :blk .{ .float = f };
        },
        .number_string => |s| .{ .number_string = try allocator.dupe(u8, s) },
        .string => |s| .{ .string = try allocator.dupe(u8, s) },
        .array => |arr| blk: {
            var value_array = std.array_list.Managed(Value).init(allocator);
            errdefer {
                for (value_array.items) |*item| {
                    item.deinit(allocator);
                }
                value_array.deinit();
            }
            try value_array.ensureTotalCapacity(arr.items.len);
            for (arr.items) |item| {
                const normalized = try normalizeJsonValue(allocator, item);
                try value_array.append(normalized);
            }
            const owned_slice = try value_array.toOwnedSlice();
            const result_arr = Value.Array{ .items = owned_slice, .capacity = owned_slice.len };
            break :blk .{ .array = result_arr };
        },
        .object => |obj| blk: {
            var value_object = Value.Object.init(allocator);
            errdefer {
                var it = value_object.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                value_object.deinit();
            }
            try value_object.ensureTotalCapacity(@intCast(obj.count()));
            var it = obj.iterator();
            while (it.next()) |entry| {
                const key = try allocator.dupe(u8, entry.key_ptr.*);
                errdefer allocator.free(key);
                const normalized = try normalizeJsonValue(allocator, entry.value_ptr.*);
                errdefer normalized.deinit(allocator);
                value_object.putAssumeCapacity(key, normalized);
            }
            break :blk .{ .object = value_object };
        },
    };
}

/// Type guards for checking value types

pub fn isJsonPrimitive(value: Value) bool {
    return switch (value) {
        .null, .bool, .integer, .float, .number_string, .string => true,
        else => false,
    };
}

pub fn isJsonArray(value: Value) bool {
    return value == .array;
}

pub fn isJsonObject(value: Value) bool {
    return value == .object;
}

pub fn isEmptyObject(value: Value.Object) bool {
    return value.count() == 0;
}

/// Array type detection

pub fn isArrayOfPrimitives(arr: Value.Array) bool {
    if (arr.items.len == 0) return true;
    for (arr.items) |item| {
        if (!isJsonPrimitive(item)) return false;
    }
    return true;
}

pub fn isArrayOfArrays(arr: Value.Array) bool {
    if (arr.items.len == 0) return true;
    for (arr.items) |item| {
        if (item != .array) return false;
    }
    return true;
}

pub fn isArrayOfObjects(arr: Value.Array) bool {
    if (arr.items.len == 0) return true;
    for (arr.items) |item| {
        if (item != .object) return false;
    }
    return true;
}
