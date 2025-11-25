const std = @import("std");
const testing = std.testing;

const json_sample =
    \\{
    \\  "name": "Jassiel",
    \\  "age": 23
    \\}
    \\
;

const Sample = struct {
    name: []const u8,
    age: u64,

    // One would have to implement a generic formatter for TOON similar to `std.json.fmt` to use it with the `{f}` format specifier.
    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("TestStruct{{ .name = \"{s}\", .age = {d} }}", .{ self.name, self.age });
    }
};

const struct_sample = Sample{ .name = "Jassiel", .age = 23 };

test "Parsing with fixed schema" {
    const parsed = try std.json.parseFromSlice(Sample, testing.allocator, json_sample, .{});
    defer parsed.deinit();

    std.debug.print("Parsed fixed JSON:\n{f}\n", .{parsed.value});

    std.debug.print("Formatted parsed fixed JSON:\n{f}\n", .{std.json.fmt(parsed.value, .{})});
}

test "Stringifying with fixed schema (using Writergate)" {
    var json_buffer: [256]u8 = undefined;
    var body_writer = std.Io.Writer.fixed(json_buffer[0..]);

    std.json.Stringify.value(struct_sample, .{}, &body_writer) catch |err| {
        std.debug.print("Stringifying JSON failed with:\n{s}\n", .{@errorName(err)});
    };

    const body = std.Io.Writer.buffered(&body_writer);

    std.debug.print("Stringified fixed JSON:\n{s}\n", .{body});
}

test "Parsing with variable schema" {
    const parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, json_sample, .{});
    defer parsed.deinit();

    const parsed_val = @as(std.json.Value, parsed.value);
    std.debug.print("Formatted parsed variable JSON:\n{f}\n", .{std.json.fmt(parsed_val, .{})});
    const name = parsed_val.object.get("name").?.string;
    const age = parsed_val.object.get("age").?.integer;

    std.debug.print("Name: {s}, Age: {d}\n", .{ name, age });
}

test "Stringifying with variable schema" {
    var out = std.Io.Writer.Allocating.init(testing.allocator);
    defer out.deinit();

    const writer = &out.writer;

    try std.json.Stringify.value(struct_sample, .{}, writer);
    const sample_str = out.written();

    std.debug.print("Stringified variable JSON:\n{s}\n", .{sample_str});
}

test "Stringifying with variable schema (using JSON Object Map or Array Hash Map with Allocator)" {
    // Create the root object as a Value
    var root_obj = std.json.ObjectMap.init(testing.allocator);
    defer root_obj.deinit();

    try root_obj.put("name", .{ .string = "Alice" });
    try root_obj.put("age", .{ .integer = 30 });

    // Create an array
    var tags_array = std.json.Array.init(testing.allocator);
    defer tags_array.deinit();
    try tags_array.append(.{ .string = "developer" });
    try tags_array.append(.{ .string = "zig" });

    try root_obj.put("tags", .{ .array = tags_array });

    // Wrap in a Value
    const root_value = std.json.Value{ .object = root_obj };

    // Use ArrayList(u8) as the buffer
    var list = std.array_list.Managed(u8).init(testing.allocator);
    defer list.deinit();

    var out = std.Io.Writer.Allocating.init(testing.allocator);
    defer out.deinit();

    const writer = &out.writer;

    try std.json.Stringify.value(root_value, .{}, writer);
    const sample_str = out.written();

    std.debug.print("Stringified JSON:\n{s}\n", .{sample_str});
}
