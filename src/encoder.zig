const std = @import("std");
const types = @import("types.zig");
const Value = types.Value;
const EncodeOptions = types.EncodeOptions;
const Delimiter = types.Delimiter;

pub fn encode(allocator: std.mem.Allocator, value: Value, options: EncodeOptions) ![]const u8 {
    var list: std.ArrayList(u8) = .{};
    errdefer list.deinit(allocator);

    try encodeValue(&list, value, options, 0, allocator);
    return list.toOwnedSlice(allocator);
}

fn encodeValue(writer: *std.ArrayList(u8), value: Value, options: EncodeOptions, depth: usize, allocator: std.mem.Allocator) anyerror!void {
    switch (value) {
        .null => try writer.appendSlice(allocator, "null"),
        .bool => |b| try writer.appendSlice(allocator, if (b) "true" else "false"),
        .number => |n| {
            // Simple number formatting
            const min_i64: f64 = @floatFromInt(std.math.minInt(i64));
            const max_i64: f64 = @floatFromInt(std.math.maxInt(i64));
            if (@floor(n) == n and n >= min_i64 and n <= max_i64) {
                try std.fmt.format(writer.writer(allocator), "{d}", .{@as(i64, @intFromFloat(n))});
            } else {
                try std.fmt.format(writer.writer(allocator), "{d}", .{n});
            }
        },
        .string => |s| try encodeString(writer, s, options.delimiter, allocator),
        .array => |arr| try encodeArray(writer, arr, options, depth, null, allocator),
        .object => |obj| try encodeObject(writer, obj, options, depth, allocator),
    }
}

fn encodeString(writer: *std.ArrayList(u8), s: []const u8, delimiter: Delimiter, allocator: std.mem.Allocator) anyerror!void {
    if (needsQuoting(s, delimiter)) {
        try writer.append(allocator, '"');
        for (s) |c| {
            switch (c) {
                '\n' => try writer.appendSlice(allocator, "\\n"),
                '\r' => try writer.appendSlice(allocator, "\\r"),
                '\t' => try writer.appendSlice(allocator, "\\t"),
                '\\' => try writer.appendSlice(allocator, "\\\\"),
                '"' => try writer.appendSlice(allocator, "\\\""),
                else => try writer.append(allocator, c),
            }
        }
        try writer.append(allocator, '"');
    } else {
        try writer.appendSlice(allocator, s);
    }
}

fn needsQuoting(s: []const u8, delimiter: Delimiter) bool {
    if (s.len == 0) return true;

    // Check if it looks like a literal
    if (std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "false") or std.mem.eql(u8, s, "null")) {
        return true;
    }

    // Check if it looks like a number
    if (looksLikeNumber(s)) return true;

    // Check for special characters
    const delim_char = delimiter.toChar();
    for (s) |c| {
        if (c == delim_char or c == '\n' or c == '\r' or c == '"' or c == '\\' or c == ':' or c == '[' or c == ']' or c == '{' or c == '}' or c == ' ') {
            return true;
        }
    }

    return false;
}

fn looksLikeNumber(s: []const u8) bool {
    if (s.len == 0) return false;
    var i: usize = 0;
    if (s[0] == '-') i = 1;
    if (i >= s.len) return false;

    var has_digit = false;
    while (i < s.len) : (i += 1) {
        if (s[i] >= '0' and s[i] <= '9') {
            has_digit = true;
        } else if (s[i] == '.') {
            // Allow decimal point
        } else {
            return false;
        }
    }
    return has_digit;
}

fn encodeObject(writer: *std.ArrayList(u8), obj: std.StringHashMap(Value), options: EncodeOptions, depth: usize, allocator: std.mem.Allocator) anyerror!void {
    var iter = obj.iterator();
    var first = true;
    while (iter.next()) |entry| {
        if (depth > 0) {
            try writer.append(allocator, '\n');
            try writeIndent(writer, depth, options.indent, allocator);
        } else {
            // For top-level objects, add newline between entries
            if (!first) {
                try writer.append(allocator, '\n');
            }
            first = false;
        }

        try encodeString(writer, entry.key_ptr.*, options.delimiter, allocator);
        try writer.append(allocator, ':');

        switch (entry.value_ptr.*) {
            .object, .array => {
                try encodeValue(writer, entry.value_ptr.*, options, depth + 1, allocator);
            },
            else => {
                try writer.append(allocator, ' ');
                try encodeValue(writer, entry.value_ptr.*, options, depth, allocator);
            },
        }
    }
}

fn encodeArray(writer: *std.ArrayList(u8), arr: []Value, options: EncodeOptions, depth: usize, key: ?[]const u8, allocator: std.mem.Allocator) anyerror!void {
    if (key) |k| {
        try encodeString(writer, k, options.delimiter, allocator);
    }

    if (arr.len == 0) {
        try writer.appendSlice(allocator, "[0]:");
        return;
    }

    // Check if it's a tabular array (all objects with same keys and primitive values)
    const tabular_info = try detectTabular(arr, allocator);
    defer if (tabular_info) |info| allocator.free(info.fields);

    if (tabular_info) |info| {
        // Tabular format
        try writer.append(allocator, '[');
        if (options.length_marker) {
            try writer.append(allocator, '#');
        }
        try std.fmt.format(writer.writer(allocator), "{d}", .{arr.len});
        try writer.appendSlice(allocator, "]{");

        // Write field list
        for (info.fields, 0..) |field, i| {
            if (i > 0) try writer.append(allocator, options.delimiter.toChar());
            try encodeString(writer, field, options.delimiter, allocator);
        }
        try writer.appendSlice(allocator, "}:");

        // Write rows
        for (arr) |item| {
            try writer.append(allocator, '\n');
            try writeIndent(writer, depth + 1, options.indent, allocator);

            const obj = item.object;
            for (info.fields, 0..) |field, i| {
                if (i > 0) try writer.append(allocator, options.delimiter.toChar());
                if (obj.get(field)) |value| {
                    try encodeValue(writer, value, options, depth, allocator);
                }
            }
        }
        return;
    }

    // Write array header: key[length]:
    try writer.append(allocator, '[');
    if (options.length_marker) {
        try std.fmt.format(writer.writer(allocator), "#", .{});
    }
    try std.fmt.format(writer.writer(allocator), "{d}", .{arr.len});
    try writer.appendSlice(allocator, "]:");

    // Check if all elements are primitives
    const all_primitives = blk: {
        for (arr) |item| {
            switch (item) {
                .object, .array => break :blk false,
                else => {},
            }
        }
        break :blk true;
    };

    if (all_primitives) {
        // Inline array
        try writer.append(allocator, ' ');
        for (arr, 0..) |item, i| {
            if (i > 0) try writer.append(allocator, options.delimiter.toChar());
            try encodeValue(writer, item, options, depth, allocator);
        }
    } else {
        // Multi-line array with list items
        for (arr) |item| {
            try writer.append(allocator, '\n');
            try writeIndent(writer, depth + 1, options.indent, allocator);
            try writer.appendSlice(allocator, "- ");
            try encodeValue(writer, item, options, depth + 1, allocator);
        }
    }
}

const TabularInfo = struct {
    fields: [][]const u8,
};

fn detectTabular(arr: []Value, allocator: std.mem.Allocator) !?TabularInfo {
    if (arr.len == 0) return null;

    // Check if all elements are objects
    for (arr) |item| {
        if (item != .object) return null;
    }

    // Get fields from first object
    var field_list = std.ArrayList([]const u8){};
    defer field_list.deinit(allocator);

    var iter = arr[0].object.iterator();
    while (iter.next()) |entry| {
        try field_list.append(allocator, entry.key_ptr.*);
    }

    if (field_list.items.len == 0) return null;

    // Check all objects have the same keys and only primitive values
    for (arr) |item| {
        const obj = item.object;

        // Check key count matches
        if (obj.count() != field_list.items.len) return null;

        // Check all fields exist and are primitives
        for (field_list.items) |field| {
            if (obj.get(field)) |value| {
                switch (value) {
                    .object, .array => return null,
                    else => {},
                }
            } else {
                return null; // Field missing
            }
        }
    }

    // Return owned copy of fields
    const fields = try allocator.alloc([]const u8, field_list.items.len);
    @memcpy(fields, field_list.items);
    return TabularInfo{ .fields = fields };
}

fn writeIndent(writer: *std.ArrayList(u8), depth: usize, indent: usize, allocator: std.mem.Allocator) anyerror!void {
    const spaces = depth * indent;
    var i: usize = 0;
    while (i < spaces) : (i += 1) {
        try writer.append(allocator, ' ');
    }
}
