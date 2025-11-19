const std = @import("std");
const testing = std.testing;
const fixtures_path = "src/tests/spec/tests/fixtures/decode/";

test {
    var fixtures_dir = try std.fs.cwd().openDir(fixtures_path, .{ .iterate = true });
    defer fixtures_dir.close();

    var it = fixtures_dir.iterate();

    var fixtures = std.StringHashMap(std.json.Parsed(std.json.Value)).init(testing.allocator);
    defer {
        // Free all keys AND values
        var cleanup_it = fixtures.iterator();
        while (cleanup_it.next()) |kv| {
            testing.allocator.free(kv.key_ptr.*); // Free the duplicated key
            kv.value_ptr.deinit(); // Free the parsed JSON
        }
        fixtures.deinit();
    }

    while (true) {
        const next = it.next() catch break;
        if (next == null) break;
        const entry = next.?;

        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        const fixture = try fixtures_dir.readFileAlloc(testing.allocator, entry.name, 10 * 1024 * 1024);
        defer testing.allocator.free(fixture);

        const parsed_fixture = try std.json.parseFromSlice(std.json.Value, testing.allocator, fixture, .{});

        // Duplicate the key so we own it
        const owned_key = try testing.allocator.dupe(u8, entry.name);
        try fixtures.put(owned_key, parsed_fixture);
    }

    // Print the loaded fixtures
    var it2 = fixtures.iterator();
    while (it2.next()) |entry| {
        const fmtd = std.json.fmt(entry.value_ptr.value, .{});
        std.debug.print("Loaded fixture: {s}, value: {f}\n", .{
            entry.key_ptr.*,
            fmtd,
        });
    }
}
