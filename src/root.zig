const std = @import("std");

pub fn init() !void {
    const result = std.posix.getenv("APPDIR") orelse "";
    std.debug.print("APPDIR: {s}\n", .{result});

    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const path_items = [_][]const u8{result, "usr/bin/keepassxc-cli"};
    const keepassxc_path = try std.fs.path.join(allocator, &path_items);

    const gpa = std.heap.page_allocator;

    var child = std.process.Child.init(&[_][]const u8{keepassxc_path, "--help"}, gpa);

    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    try child.spawn();

    const term = try child.wait();
    std.debug.print("Child exited with code {}\n", .{term.Exited});
}
