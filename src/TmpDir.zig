const std = @import("std");

path: []const u8,

pub fn create(allocator: std.mem.Allocator, base_name: []const u8) !@This() {
    const path = try std.fmt.allocPrint(allocator, "/tmp/.encrypter_{s}_{d}", .{ base_name, std.time.nanoTimestamp() });
    try std.fs.makeDirAbsolute(path);

    return .{ .path = path };
}

pub fn getPath(self: *const @This()) []const u8 {
    return self.path;
}

pub fn clear(self: *@This(), allocator: std.mem.Allocator) !void {
    // const name = std.fs.path.basename(self.path);

    // var dir = try std.fs.openDirAbsolute("/tmp", .{});
    // defer dir.close();
    // try dir.deleteTree(name);

    allocator.free(self.path);
    self.path = undefined;
}
