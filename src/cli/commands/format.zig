//! Format command: Format TOON files to canonical representation

const std = @import("std");
const toonz = @import("toonz");
const errors = @import("../errors.zig");

pub const Options = toonz.format.FormatOptions;

pub const Command = struct {
    input_source: InputSource,
    output_path: ?[]const u8,
    options: Options,
    check_mode: bool = false, // Only check if formatting is needed, don't modify
    in_place: bool = false, // Modify file in place
};

pub const InputSource = union(enum) {
    file: []const u8,
    stdin: void,
};

pub fn parseCommand(
    args: []const []const u8,
    allocator: std.mem.Allocator,
    input_path: ?[]const u8,
    output_path: ?[]const u8,
) !Command {
    var opts = Options{};
    var parsed_input_path = input_path;
    var parsed_output_path = output_path;
    var check_mode = false;
    var in_place = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i >= args.len) return error.InvalidArguments;
            parsed_output_path = try allocator.dupe(u8, args[i]);
        } else if (std.mem.startsWith(u8, arg, "-o=") or std.mem.startsWith(u8, arg, "--output=")) {
            const eq_pos = std.mem.indexOfScalar(u8, arg, '=').?;
            parsed_output_path = try allocator.dupe(u8, arg[eq_pos + 1 ..]);
        } else if (std.mem.startsWith(u8, arg, "--indent=")) {
            const eq_pos = std.mem.indexOfScalar(u8, arg, '=').?;
            const indent_str = arg[eq_pos + 1 ..];
            opts.indent = try std.fmt.parseInt(u64, indent_str, 10);
        } else if (std.mem.eql(u8, arg, "--indent")) {
            i += 1;
            if (i >= args.len) return error.InvalidArguments;
            opts.indent = try std.fmt.parseInt(u64, args[i], 10);
        } else if (std.mem.startsWith(u8, arg, "--delimiter=")) {
            const eq_pos = std.mem.indexOfScalar(u8, arg, '=').?;
            const delim_str = arg[eq_pos + 1 ..];
            if (delim_str.len != 1) return error.InvalidArguments;
            opts.delimiter = delim_str[0];
        } else if (std.mem.eql(u8, arg, "--delimiter")) {
            i += 1;
            if (i >= args.len) return error.InvalidArguments;
            if (args[i].len != 1) return error.InvalidArguments;
            opts.delimiter = args[i][0];
        } else if (std.mem.eql(u8, arg, "--key-folding=off") or std.mem.eql(u8, arg, "--keyFolding=off")) {
            opts.key_folding = .off;
        } else if (std.mem.eql(u8, arg, "--key-folding=safe") or std.mem.eql(u8, arg, "--keyFolding=safe")) {
            opts.key_folding = .safe;
        } else if (std.mem.startsWith(u8, arg, "--flatten-depth=")) {
            const eq_pos = std.mem.indexOfScalar(u8, arg, '=').?;
            const depth_str = arg[eq_pos + 1 ..];
            opts.flatten_depth = try std.fmt.parseInt(u64, depth_str, 10);
        } else if (std.mem.eql(u8, arg, "--flatten-depth")) {
            i += 1;
            if (i >= args.len) return error.InvalidArguments;
            opts.flatten_depth = try std.fmt.parseInt(u64, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--check") or std.mem.eql(u8, arg, "-c")) {
            check_mode = true;
        } else if (std.mem.eql(u8, arg, "--in-place") or std.mem.eql(u8, arg, "-i")) {
            in_place = true;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            if (parsed_input_path == null) {
                parsed_input_path = try allocator.dupe(u8, arg);
            } else {
                return error.InvalidArguments;
            }
        }
    }

    // Validate options
    if (in_place and check_mode) {
        return error.InvalidArguments; // Can't use both
    }

    if (in_place and parsed_input_path == null) {
        return error.InvalidArguments; // Need a file for in-place editing
    }

    const input_source: InputSource = if (parsed_input_path) |path|
        if (std.mem.eql(u8, path, "-"))
            InputSource{ .stdin = {} }
        else
            InputSource{ .file = path }
    else
        InputSource{ .stdin = {} };

    return Command{
        .input_source = input_source,
        .output_path = parsed_output_path,
        .options = opts,
        .check_mode = check_mode,
        .in_place = in_place,
    };
}

pub fn run(cmd: Command, allocator: std.mem.Allocator) !void {
    // Read input
    const input_content = try readInput(cmd.input_source, allocator);
    defer allocator.free(input_content);

    // Format the TOON content
    const formatted_output = toonz.format.formatToon(input_content, cmd.options, allocator) catch |err| {
        const stderr_file = std.fs.File.stderr();
        switch (err) {
            error.SyntaxError => try stderr_file.writeAll("Error: Invalid TOON syntax in input\n"),
            error.OutOfMemory => try stderr_file.writeAll("Error: Out of memory\n"),
            else => {
                var buf: [256]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "Error: Failed to format TOON: {}\n", .{err}) catch "Error: Failed to format TOON\n";
                try stderr_file.writeAll(msg);
            },
        }
        return err;
    };
    defer allocator.free(formatted_output);

    if (cmd.check_mode) {
        // Check mode: compare formatted with original
        if (!std.mem.eql(u8, input_content, formatted_output)) {
            const stderr_file = std.fs.File.stderr();
            try stderr_file.writeAll("File is not properly formatted\n");
            return error.FormattingNeeded;
        }
        // File is already formatted correctly
        return;
    }

    if (cmd.in_place) {
        // In-place mode: write back to the same file
        switch (cmd.input_source) {
            .file => |path| {
                try std.fs.cwd().writeFile(.{ .sub_path = path, .data = formatted_output });
            },
            .stdin => return error.InvalidArguments,
        }
    } else {
        // Write output
        try writeOutput(formatted_output, cmd.output_path);
    }
}

fn readInput(source: InputSource, allocator: std.mem.Allocator) ![]const u8 {
    switch (source) {
        .file => |path| {
            const content = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
            return content;
        },
        .stdin => {
            const stdin_file = std.fs.File.stdin();
            var buffer = std.array_list.Managed(u8).init(allocator);
            defer buffer.deinit();

            var read_buf: [4096]u8 = undefined;
            while (true) {
                const bytes_read = try stdin_file.read(read_buf[0..]);
                if (bytes_read == 0) break;
                try buffer.appendSlice(read_buf[0..bytes_read]);
            }

            return try buffer.toOwnedSlice();
        },
    }
}

fn writeOutput(content: []const u8, output_path: ?[]const u8) !void {
    if (output_path) |path| {
        if (std.mem.eql(u8, path, "-")) {
            const stdout_file = std.fs.File.stdout();
            try stdout_file.writeAll(content);
        } else {
            try std.fs.cwd().writeFile(.{ .sub_path = path, .data = content });
        }
    } else {
        const stdout_file = std.fs.File.stdout();
        try stdout_file.writeAll(content);
    }
}
