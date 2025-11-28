const std = @import("std");
const testing = std.testing;
const toonz = @import("toonz");
const Fixture = @import("Fixture.zig");

test "Stringify specification fixtures" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const fixture_files = try Fixture.loadFromDir(allocator, "spec/tests/fixtures/encode");

    var fxt_it = fixture_files.iterator();
    while (fxt_it.next()) |entry| {
        const fixture = try std.json.parseFromValue(Fixture, allocator, entry.value_ptr.*, .{});

        std.debug.print("Description: {s}\n", .{fixture.value.description});

        for (fixture.value.tests, 0..) |test_case, i| {
            std.debug.print("- Test {}: {s}\n", .{ i + 1, test_case.name });

            // Build stringify options from fixture options
            var stringify_options: toonz.serialize.Options = .{};
            if (test_case.options) |opts| {
                if (opts.indent) |indent| {
                    stringify_options.indent = @intCast(indent);
                }
                if (opts.delimiter) |delim| {
                    if (std.mem.eql(u8, delim, ",")) {
                        stringify_options.delimiter = ',';
                    } else if (std.mem.eql(u8, delim, "\t")) {
                        stringify_options.delimiter = '\t';
                    } else if (std.mem.eql(u8, delim, "|")) {
                        stringify_options.delimiter = '|';
                    }
                }
                if (opts.keyFolding) |folding| {
                    if (std.mem.eql(u8, folding, "safe")) {
                        stringify_options.key_folding = .safe;
                    } else {
                        stringify_options.key_folding = .off;
                    }
                }
                if (opts.flattenDepth) |depth| {
                    stringify_options.flatten_depth = @intCast(depth);
                }
            }

            if (test_case.shouldError) {
                // Test expects an error - check that stringifying fails
                const result = toonz.Stringify.value(test_case.input, stringify_options, allocator);
                if (result) |_| {
                    // Stringifying succeeded when it should have failed
                    return error.TestExpectedError;
                } else |_| {
                    // Stringifying failed as expected
                }
                continue;
            } else {
                const stringified = try toonz.Stringify.value(test_case.input, stringify_options, allocator);
                defer allocator.free(stringified);

                std.debug.print("Input JSON:\n", .{});
                std.debug.print("{f}\n", .{std.json.fmt(test_case.input, .{})});
                std.debug.print("Output TOON:\n{s}\n", .{stringified});
                std.debug.print("Expected TOON:\n{s}\n", .{test_case.expected.string});

                // TODO: Compare stringified with test_case.expected.string
                // For now, just check that it doesn't crash
                std.debug.print("Length: {} vs {}\n", .{ stringified.len, test_case.expected.string.len });
            }
        }
    }
}
