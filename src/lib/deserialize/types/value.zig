const std = @import("std");
const Allocator = std.mem.Allocator;
const number = @import("number.zig");
const parseStruct = @import("object.zig").parseStruct;
const boolean = @import("boolean.zig");
const isNull = @import("null.zig").isNull;
const string = @import("string.zig");
const Scanner = @import("../Scanner.zig");
const Context = @import("../Context.zig");
const Value = @import("../../Value.zig").Value;

/// Parse a primitive value (int, float, bool, string) from a given content.
pub fn parsePrimitiveValue(comptime T: type, val: []const u8, allocator: Allocator) !T {
    const type_info = @typeInfo(T);

    return switch (type_info) {
        .int => try number.parseInt(T, val),
        .float => try number.parseFloat(T, val),
        .bool => try boolean.parseBool(val),
        .pointer => |ptr| blk: {
            if (ptr.size == .slice and ptr.child == u8) {
                break :blk try string.parseString(val, allocator);
            }
            return error.TypeMismatch;
        },
        else => error.TypeMismatch,
    };
}

/// Parse a nested value (struct, array, etc.) from the scanner.
pub fn parseNestedValue(
    comptime T: type,
    scanner: *Scanner,
    parent_indent: usize,
    ctx: *Context,
) !T {
    const next_line = scanner.peek() orelse return error.UnexpectedEof;

    // Nested content must be indented more
    if (next_line.indent <= parent_indent) return error.InvalidIndentation;

    return parseValue(T, scanner, next_line.indent, ctx);
}

/// Parse an inline value (int, float, bool, string, optional) from a given content.
pub fn parseInlineValue(
    comptime T: type,
    content: []const u8,
    ctx: *Context,
) !T {
    const type_info = @typeInfo(T);

    return switch (type_info) {
        .int => try number.parseInt(T, content),
        .float => try number.parseFloat(T, content),
        .bool => try boolean.parseBool(content),
        .pointer => |ptr| blk: {
            if (ptr.size == .slice and ptr.child == u8) {
                break :blk try string.parseString(content, ctx.allocator);
            }
            return error.TypeMismatch;
        },
        .optional => |opt| blk: {
            if (isNull(content)) {
                break :blk null;
            }
            break :blk try parseInlineValue(opt.child, content, ctx);
        },
        else => error.TypeMismatch,
    };
}

/// Parse a value of type T from the scanner, handling both inline and nested values.
pub fn parseValue(comptime T: type, scanner: *Scanner, base_indent: usize, ctx: *Context) !T {
    if (ctx.depth >= ctx.options.max_depth) return error.SyntaxError;
    ctx.depth += 1;
    defer ctx.depth -= 1;
    const type_info = @typeInfo(T);

    return switch (type_info) {
        .@"struct" => try parseStruct(T, scanner, base_indent, ctx),
        .pointer => |ptr| blk: {
            if (ptr.size == .slice) {
                if (ptr.child == u8) {
                    // String - read inline
                    const line = scanner.peek() orelse return error.UnexpectedEof;
                    _ = scanner.next();
                    break :blk try string.parseString(line.content, ctx.allocator);
                }
                // Array/slice - should be handled by parseStruct for struct fields
                return error.TypeMismatch;
            }
            return error.TypeMismatch;
        },
        .int, .comptime_int => blk: {
            const line = scanner.peek() orelse return error.UnexpectedEof;
            _ = scanner.next();
            break :blk try number.parseInt(T, line.content);
        },

        .float, .comptime_float => blk: {
            const line = scanner.peek() orelse return error.UnexpectedEof;
            _ = scanner.next();
            break :blk try number.parseFloat(T, line.content);
        },

        .bool => blk: {
            const line = scanner.peek() orelse return error.UnexpectedEof;
            _ = scanner.next();
            break :blk try boolean.parseBool(line.content);
        },

        .optional => |opt| blk: {
            const line = scanner.peek() orelse return null;
            if (isNull(line.content)) {
                _ = scanner.next();
                break :blk null;
            }
            break :blk try parseValue(opt.child, scanner, base_indent, ctx);
        },
        .@"union" => |u| blk: {
            // Check if this is our Value type
            if (u.tag_type != null and T == Value) {
                break :blk try parseDynamicValue(scanner, base_indent, ctx);
            }
            @compileError("Cannot parse union type: " ++ @typeName(T));
        },
        else => @compileError("Cannot parse type: " ++ @typeName(T)),
    };
}

/// Parse a dynamic value (TOONZ Value type) from the scanner.
fn parseDynamicValue(scanner: *Scanner, base_indent: usize, ctx: *Context) (Allocator.Error || error{InvalidEscapeSequence})!Value {
    const line = scanner.peek() orelse return .null;

    // Check if this is an object or array by looking at the structure
    // If the current line has a key:value format, it's likely an object/array field
    // If the next line is indented, it's a nested structure

    const content = std.mem.trim(u8, line.content, " \t");

    // Check for null
    if (isNull(content)) {
        _ = scanner.next();
        return .null;
    }

    // Check for boolean
    if (boolean.parseBool(content)) |b| {
        _ = scanner.next();
        return .{ .bool = b };
    } else |_| {}

    // Check for number
    if (number.parseInt(i64, content)) |i| {
        _ = scanner.next();
        return .{ .integer = i };
    } else |_| {}

    if (number.parseFloat(f64, content)) |f| {
        _ = scanner.next();
        return .{ .float = f };
    } else |_| {}

    // Check if there's a next line that's indented (nested structure)
    const peek_next = scanner.peekAhead(1);
    if (peek_next) |next| {
        if (next.indent > base_indent) {
            // This is a nested structure, could be object or array
            // We need to parse it as an object
            _ = scanner.next();
            return try parseDynamicObject(scanner, base_indent, ctx);
        }
    }

    // Otherwise, it's a string
    _ = scanner.next();
    const str = try string.parseString(content, ctx.allocator);
    return .{ .string = str };
}

/// Parse a dynamic object (for Value type)
fn parseDynamicObject(scanner: *Scanner, parent_indent: usize, ctx: *Context) (Allocator.Error || error{InvalidEscapeSequence})!Value {
    var object = Value.Object.init(ctx.allocator);
    errdefer {
        var it = object.iterator();
        while (it.next()) |entry| {
            ctx.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(ctx.allocator);
        }
        object.deinit();
    }

    while (scanner.peek()) |line| {
        if (line.indent <= parent_indent) break;
        if (line.indent != parent_indent + ctx.options.indent) continue;

        _ = scanner.next();

        // Parse key-value pair
        const colon_pos = std.mem.indexOf(u8, line.content, ":") orelse continue;
        const key_str = std.mem.trim(u8, line.content[0..colon_pos], " \t");
        const key = try ctx.allocator.dupe(u8, key_str);
        errdefer ctx.allocator.free(key);

        const value_str = std.mem.trim(u8, line.content[colon_pos + 1 ..], " \t");

        // Check if value is inline or nested
        var val: Value = undefined;
        if (value_str.len > 0) {
            // Inline value
            if (isNull(value_str)) {
                val = .null;
            } else if (boolean.parseBool(value_str)) |b| {
                val = .{ .bool = b };
            } else |_| {
                if (number.parseInt(i64, value_str)) |i| {
                    val = .{ .integer = i };
                } else |_| {
                    if (number.parseFloat(f64, value_str)) |f| {
                        val = .{ .float = f };
                    } else |_| {
                        const str = try string.parseString(value_str, ctx.allocator);
                        val = .{ .string = str };
                    }
                }
            }
        } else {
            // Nested value
            const peek_next = scanner.peek();
            if (peek_next) |next| {
                if (next.indent > line.indent) {
                    val = try parseDynamicValue(scanner, line.indent, ctx);
                } else {
                    val = .null;
                }
            } else {
                val = .null;
            }
        }

        try object.put(key, val);
    }

    return .{ .object = object };
}

/// Parse individual fields of type T from the given content.
pub fn parseFieldValue(comptime T: type, val: []const u8, allocator: Allocator) !T {
    const type_info = @typeInfo(T);

    return switch (type_info) {
        .int => try number.parseInt(T, val),
        .float => try number.parseFloat(T, val),
        .bool => try boolean.parseBool(val),
        .pointer => |ptr| blk: {
            if (ptr.size == .slice and ptr.child == u8) {
                break :blk try string.parseString(val, allocator);
            }
            return error.TypeMismatch;
        },
        .optional => |opt| blk: {
            if (isNull(val)) {
                break :blk null;
            }
            break :blk try parseFieldValue(opt.child, val, allocator);
        },
        else => error.TypeMismatch,
    };
}
