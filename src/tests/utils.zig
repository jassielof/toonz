const std = @import("std");
/// Loads all JSON files from a directory into a StringHashMap.
/// Caller owns the returned map and must call deinit() on it.
/// Uses the provided allocator for all allocations.
pub fn loadJsonFixtures(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
) !std.StringHashMap(std.json.Value) {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var fixtures = std.StringHashMap(std.json.Value).init(allocator);
    errdefer fixtures.deinit();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".json")) continue;

        const content = try dir.readFileAlloc(allocator, entry.name, 10 * 1024 * 1024);
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
        try fixtures.put(entry.name, parsed.value);
    }

    return fixtures;
}
