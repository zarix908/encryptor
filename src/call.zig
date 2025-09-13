const std = @import("std");
const errors = @import("errors.zig");

pub const Stdin = union(enum) {
    Ignore,
    Inherit,
    Pipe: []u8,

    fn to_file_input(self: Stdin) std.process.Child.StdIo {
        return switch (self) {
            .Ignore => .Ignore,
            .Inherit => .Inherit,
            .Pipe => .Pipe,
        };
    }
};

pub fn call(cmd_args_len: comptime_int, args: struct {
    path_allocator: std.mem.Allocator,
    executable: []const u8,
    cmd_args: *const [cmd_args_len][]const u8,
    appdir: []const u8,
    input: Stdin,
    output: std.process.Child.StdIo,
}) !?[]u8 {
    var path_items = [_][]const u8{ args.appdir, args.executable };
    const exec_path = try std.fs.path.join(args.path_allocator, &path_items);
    defer args.path_allocator.free(exec_path);

    var argv: [cmd_args_len + 1][]const u8 = undefined;
    argv[0] = exec_path;
    @memmove(argv[1..], args.cmd_args);

    var child = std.process.Child.init(&argv, std.heap.page_allocator);

    child.stdin_behavior = args.input.to_file_input();
    child.stdout_behavior = args.output;
    child.stderr_behavior = args.output;
    child.expand_arg0 = .no_expand;
    child.progress_node = std.Progress.Node.none;

    var stdout: std.ArrayList(u8) = .empty;
    defer stdout.deinit(std.heap.page_allocator);
    var stderr: std.ArrayList(u8) = .empty;
    defer stderr.deinit(std.heap.page_allocator);

    try child.spawn();
    errdefer {
        _ = child.kill() catch {};
    }

    if (args.input == .Pipe) {
        if (child.stdin) |stdin| {
            var writer = stdin.writer(&.{});
            const in = &writer.interface;
            try in.writeAll(args.input.Pipe);
            try in.flush();
            stdin.close();
            child.stdin = null;
        }
    }

    if (child.stdout_behavior == .Pipe) {
        try child.collectOutput(std.heap.page_allocator, &stdout, &stderr, 50 * 1024);
    }

    const term = try child.wait();
    if (term.Exited != 0) {
        if (child.stderr_behavior == .Pipe) {
            const stderr_slice = try stderr.toOwnedSlice(std.heap.page_allocator);
            std.debug.print("stderr: {s}", .{stderr_slice});
        }

        return errors.Err.NonNilExitCode;
    }

    if (child.stdout_behavior == .Pipe) {
        return try stdout.toOwnedSlice(std.heap.page_allocator);
    }

    return null;
}
