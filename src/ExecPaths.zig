const std = @import("std");

keepassxc: []const u8,
age: []const u8,
age_keygen: []const u8,

pub fn init(allocator: std.mem.Allocator, base_path: []const u8, bin_subdir: []const u8) !@This() {
    const keepassxc = try std.fs.path.join(allocator, &.{ base_path, bin_subdir, "keepassxc-cli" });
    const age = try std.fs.path.join(allocator, &.{ base_path, bin_subdir, "age" });
    const age_keygen = try std.fs.path.join(allocator, &.{ base_path, bin_subdir, "age-keygen" });

    return .{ .keepassxc = keepassxc, .age = age, .age_keygen = age_keygen };
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    allocator.free(self.keepassxc);
    self.keepassxc = undefined;

    allocator.free(self.age);
    self.age = undefined;

    allocator.free(self.age_keygen);
    self.age_keygen = undefined;
}
