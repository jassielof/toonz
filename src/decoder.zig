const std = @import("std");
const types = @import("types.zig");
const Value = types.Value;
const DecodeOptions = types.DecodeOptions;
const Delimiter = types.Delimiter;

pub fn decode(allocator: std.mem.Allocator, input: []const u8, options: DecodeOptions) !Value {
    var parser = Parser{
        .allocator = allocator,
        .input = input,
        .pos = 0,
        .line = 1,
        .options = options,
    };

    return try parser.parseValue(0);
}

const Parser = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    pos: usize,
    line: usize,
    options: DecodeOptions,

    fn parseValue(self: *Parser, indent_level: usize) anyerror!Value {
        self.skipWhitespace();

        if (self.pos >= self.input.len) {
            return Value{ .object = std.StringHashMap(Value).init(self.allocator) };
        }

        // Check for root array (starts with identifier followed by '[')
        if (indent_level == 0) {
            var i = self.pos;
            while (i < self.input.len and self.input[i] != '[' and self.input[i] != ':' and self.input[i] != '\n') {
                i += 1;
            }
            if (i < self.input.len and self.input[i] == '[') {
                // This is a root array
                return try self.parseRootArray();
            }
        }

        // Check for array header
        if (self.peekArrayHeader()) {
            return try self.parseArray(indent_level, null);
        }

        // Check for object (key: value)
        if (try self.peekObjectKey()) {
            return try self.parseObject(indent_level);
        }

        // Parse as primitive
        return try self.parsePrimitive();
    }

    fn parseRootArray(self: *Parser) anyerror!Value {
        // Skip key (if present) - just move to '['
        while (self.pos < self.input.len and self.input[self.pos] != '[') {
            self.pos += 1;
        }

        return try self.parseArray(0, null);
    }

    fn parseObject(self: *Parser, indent_level: usize) anyerror!Value {
        var obj = std.StringHashMap(Value).init(self.allocator);
        errdefer {
            var iter = obj.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.deinit(self.allocator);
            }
            obj.deinit();
        }

        while (self.pos < self.input.len) {
            // For nested objects, check if we're at the expected indent level
            if (indent_level > 0) {
                const current_indent = self.getCurrentIndent();
                if (current_indent < indent_level) break;
                if (current_indent > indent_level) break;
                // Skip the indent spaces
                self.pos += indent_level * self.options.indent;
            } else {
                self.skipWhitespace();
                if (self.pos >= self.input.len) break;
            }

            // Parse key
            const key = try self.parseKey();

            // Expect colon
            self.skipSpaces();
            if (self.pos >= self.input.len or self.input[self.pos] != ':') {
                self.allocator.free(key);
                return error.ExpectedColon;
            }
            self.pos += 1;

            // Check for array
            self.skipSpaces();
            if (self.pos < self.input.len and self.input[self.pos] == '[') {
                const value = try self.parseArray(indent_level + 1, key);
                try obj.put(key, value);
            } else {
                self.skipSpaces();

                // Check if next line is indented (nested object)
                if (self.pos >= self.input.len or self.input[self.pos] == '\n') {
                    if (self.pos < self.input.len) self.pos += 1; // Skip newline
                    const next_indent = self.getCurrentIndent();
                    if (next_indent > indent_level) {
                        const value = try self.parseObject(next_indent);
                        try obj.put(key, value);
                        // Don't skip to next line - parseObject already consumed everything
                        continue;
                    } else {
                        // Empty object
                        try obj.put(key, Value{ .object = std.StringHashMap(Value).init(self.allocator) });
                    }
                } else {
                    const value = try self.parsePrimitive();
                    try obj.put(key, value);
                }
            }

            self.skipToNextLine();
        }

        return Value{ .object = obj };
    }

    fn parseArray(self: *Parser, indent_level: usize, key: ?[]const u8) anyerror!Value {
        _ = key;
        _ = indent_level;

        // Parse array header: [length]:
        if (self.input[self.pos] != '[') return error.ExpectedArrayHeader;
        self.pos += 1;

        // Skip optional # length marker
        if (self.pos < self.input.len and self.input[self.pos] == '#') {
            self.pos += 1;
        }

        // Parse length
        const len_start = self.pos;
        while (self.pos < self.input.len and self.input[self.pos] >= '0' and self.input[self.pos] <= '9') {
            self.pos += 1;
        }
        const length = try std.fmt.parseInt(usize, self.input[len_start..self.pos], 10);

        // Check for delimiter marker after length
        var delimiter = Delimiter.comma;
        if (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == '\t') {
                delimiter = .tab;
                self.pos += 1;
            } else if (c == '|') {
                delimiter = .pipe;
                self.pos += 1;
            } else if (c == ',') {
                delimiter = .comma;
                self.pos += 1;
            }
        }

        if (self.pos >= self.input.len or self.input[self.pos] != ']') {
            return error.ExpectedClosingBracket;
        }
        self.pos += 1;

        // Check for tabular field list {field1,field2,...}:
        var field_list: ?[][]const u8 = null;

        if (self.pos < self.input.len and self.input[self.pos] == '{') {
            self.pos += 1; // skip '{'

            // Delimiter is already set from array header or default
            // If not set explicitly in header, detect from field list
            if (delimiter == .comma) {
                const field_start = self.pos;
                const field_end = blk: {
                    var i = self.pos;
                    while (i < self.input.len and self.input[i] != '}') : (i += 1) {}
                    break :blk i;
                };

                const field_content = self.input[field_start..field_end];
                if (std.mem.indexOf(u8, field_content, "\t")) |_| {
                    delimiter = .tab;
                } else if (std.mem.indexOf(u8, field_content, "|")) |_| {
                    delimiter = .pipe;
                }
            }

            // Parse field names
            var fields = std.ArrayList([]const u8){};
            errdefer {
                for (fields.items) |field| {
                    self.allocator.free(field);
                }
                fields.deinit(self.allocator);
            }

            while (self.pos < self.input.len and self.input[self.pos] != '}') {
                self.skipSpaces();
                const field_name = try self.parseFieldName(delimiter);
                try fields.append(self.allocator, field_name);

                self.skipSpaces();
                if (self.pos < self.input.len and self.input[self.pos] == delimiter.toChar()) {
                    self.pos += 1; // skip delimiter
                }
            }

            if (self.pos >= self.input.len or self.input[self.pos] != '}') {
                return error.ExpectedClosingBrace;
            }
            self.pos += 1; // skip '}'

            field_list = try fields.toOwnedSlice(self.allocator);
        }
        defer if (field_list) |fl| {
            // Free field names and the array
            for (fl) |field| {
                self.allocator.free(field);
            }
            self.allocator.free(fl);
        };

        if (self.pos >= self.input.len or self.input[self.pos] != ':') {
            return error.ExpectedColon;
        }
        self.pos += 1;

        var items = try self.allocator.alloc(Value, length);
        errdefer {
            for (items[0..length]) |*item| {
                item.deinit(self.allocator);
            }
            self.allocator.free(items);
        }

        if (length == 0) {
            return Value{ .array = items };
        }

        self.skipSpaces();

        // Handle tabular rows if field_list is present
        if (field_list) |fields| {
            for (items) |*item| {
                self.skipToNextLine();
                self.skipSpaces();

                // Parse row as delimiter-separated values
                var obj = std.StringHashMap(Value).init(self.allocator);
                errdefer obj.deinit();

                for (fields, 0..) |field, i| {
                    self.skipSpaces();
                    const value = try self.parsePrimitive();
                    // Duplicate the field name for this object
                    const field_copy = try self.allocator.dupe(u8, field);
                    try obj.put(field_copy, value);

                    if (i < fields.len - 1) {
                        self.skipSpaces();
                        if (self.pos < self.input.len and self.input[self.pos] == delimiter.toChar()) {
                            self.pos += 1;
                        }
                    }
                }

                item.* = Value{ .object = obj };
            }
            return Value{ .array = items };
        }

        // Check if inline (same line) or multi-line
        if (self.pos < self.input.len and self.input[self.pos] != '\n') {
            // Inline array - detect delimiter
            const rest = self.input[self.pos..];
            if (std.mem.indexOf(u8, rest, "\t") != null) {
                delimiter = .tab;
            } else if (std.mem.indexOf(u8, rest, "|") != null) {
                delimiter = .pipe;
            }

            for (items, 0..) |*item, i| {
                self.skipSpaces();
                item.* = try self.parsePrimitive();

                if (i < length - 1) {
                    self.skipSpaces();
                    if (self.pos < self.input.len and self.input[self.pos] == delimiter.toChar()) {
                        self.pos += 1;
                    }
                }
            }
        } else {
            // Multi-line array with list items
            for (items) |*item| {
                self.skipToNextLine();
                const current_indent = self.getCurrentIndent();

                // Expect list marker
                self.skipSpaces();
                if (self.pos >= self.input.len or self.input[self.pos] != '-') {
                    return error.ExpectedListMarker;
                }
                self.pos += 1;
                self.skipSpaces();

                item.* = try self.parseValue(current_indent);
            }
        }

        return Value{ .array = items };
    }

    fn parsePrimitive(self: *Parser) anyerror!Value {
        self.skipSpaces();

        if (self.pos >= self.input.len) {
            return Value{ .null = {} };
        }

        // String (quoted or unquoted)
        if (self.input[self.pos] == '"') {
            return try self.parseQuotedString();
        }

        // Find end of token
        const start = self.pos;
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == '\n' or c == '\r' or c == ',' or c == '\t' or c == '|' or c == ' ') {
                break;
            }
            self.pos += 1;
        }

        const token = self.input[start..self.pos];

        // null
        if (std.mem.eql(u8, token, "null")) {
            return Value{ .null = {} };
        }

        // boolean
        if (std.mem.eql(u8, token, "true")) {
            return Value{ .bool = true };
        }
        if (std.mem.eql(u8, token, "false")) {
            return Value{ .bool = false };
        }

        // number
        if (std.fmt.parseFloat(f64, token)) |num| {
            return Value{ .number = num };
        } else |_| {
            // unquoted string
            const str = try self.allocator.dupe(u8, token);
            return Value{ .string = str };
        }
    }

    fn parseQuotedString(self: *Parser) anyerror!Value {
        if (self.input[self.pos] != '"') return error.ExpectedQuote;
        self.pos += 1;

        var result: std.ArrayList(u8) = .{};
        errdefer result.deinit(self.allocator);

        while (self.pos < self.input.len) {
            const c = self.input[self.pos];

            if (c == '"') {
                self.pos += 1;
                return Value{ .string = try result.toOwnedSlice(self.allocator) };
            }

            if (c == '\\') {
                self.pos += 1;
                if (self.pos >= self.input.len) return error.UnexpectedEOF;

                const escaped = self.input[self.pos];
                switch (escaped) {
                    'n' => try result.append(self.allocator, '\n'),
                    'r' => try result.append(self.allocator, '\r'),
                    't' => try result.append(self.allocator, '\t'),
                    '\\' => try result.append(self.allocator, '\\'),
                    '"' => try result.append(self.allocator, '"'),
                    else => {
                        try result.append(self.allocator, '\\');
                        try result.append(self.allocator, escaped);
                    },
                }
                self.pos += 1;
            } else {
                try result.append(self.allocator, c);
                self.pos += 1;
            }
        }

        return error.UnterminatedString;
    }

    fn parseKey(self: *Parser) anyerror![]const u8 {
        self.skipSpaces();

        if (self.pos >= self.input.len) return error.UnexpectedEOF;

        if (self.input[self.pos] == '"') {
            const val = try self.parseQuotedString();
            return val.string;
        }

        const start = self.pos;
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == ':' or c == ' ' or c == '\n' or c == '[') break;
            self.pos += 1;
        }

        return try self.allocator.dupe(u8, self.input[start..self.pos]);
    }

    fn parseFieldName(self: *Parser, delimiter: Delimiter) anyerror![]const u8 {
        self.skipSpaces();

        if (self.pos >= self.input.len) return error.UnexpectedEOF;

        if (self.input[self.pos] == '"') {
            const val = try self.parseQuotedString();
            return val.string;
        }

        const start = self.pos;
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == '}' or c == delimiter.toChar() or c == ' ' or c == '\n') break;
            self.pos += 1;
        }

        return try self.allocator.dupe(u8, self.input[start..self.pos]);
    }

    fn peekArrayHeader(self: *Parser) bool {
        var i = self.pos;
        while (i < self.input.len and self.input[i] == ' ') i += 1;
        return i < self.input.len and self.input[i] == '[';
    }

    fn peekObjectKey(self: *Parser) anyerror!bool {
        var i = self.pos;
        while (i < self.input.len) {
            const c = self.input[i];
            if (c == ':') return true;
            if (c == '\n') return false;
            i += 1;
        }
        return false;
    }

    fn getCurrentIndent(self: *Parser) usize {
        var indent: usize = 0;
        var i = self.pos;
        while (i < self.input.len and self.input[i] == ' ') {
            indent += 1;
            i += 1;
        }
        return indent / self.options.indent;
    }

    fn skipWhitespace(self: *Parser) void {
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == ' ' or c == '\n' or c == '\r') {
                if (c == '\n') self.line += 1;
                self.pos += 1;
            } else {
                break;
            }
        }
    }

    fn skipSpaces(self: *Parser) void {
        while (self.pos < self.input.len and self.input[self.pos] == ' ') {
            self.pos += 1;
        }
    }

    fn skipToNextLine(self: *Parser) void {
        while (self.pos < self.input.len) {
            if (self.input[self.pos] == '\n') {
                self.pos += 1;
                self.line += 1;
                break;
            }
            self.pos += 1;
        }
    }
};
