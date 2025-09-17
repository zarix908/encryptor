const std = @import("std");
const errors = @import("errors.zig");

pub const Stdin = union(enum) {
    Ignore,
    Inherit,
    PipeBuffer: []u8,
    PipeReader: std.io.Reader,

    fn toFileInput(self: *const Stdin) std.process.Child.StdIo {
        return switch (self.*) {
            .Ignore => .Ignore,
            .Inherit => .Inherit,
            .PipeBuffer => .Pipe,
            .PipeReader => .Pipe,
        };
    }
};

pub fn call(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    input: Stdin,
    output: std.process.Child.StdIo,
) !?[]u8 {
    var child = std.process.Child.init(argv, allocator);

    child.stdin_behavior = input.toFileInput();
    child.stdout_behavior = output;
    child.stderr_behavior = output;
    child.expand_arg0 = .no_expand;
    child.progress_node = std.Progress.Node.none;

    var stdout: std.ArrayList(u8) = .empty;
    defer stdout.deinit(allocator);
    var stderr: std.ArrayList(u8) = .empty;
    defer stderr.deinit(allocator);

    try child.spawn();
    errdefer {
        _ = child.kill() catch {};
    }

    switch (input) {
        .PipeBuffer => |buffer| {
            if (child.stdin) |stdin| {
                var writer = stdin.writer(&.{});
                const writerPtr = &writer.interface;

                try writerPtr.writeAll(buffer);
                try writerPtr.flush();

                stdin.close();
                child.stdin = null;
            }
        },
        .PipeReader => |reader| {
            if (child.stdin) |stdin| {
                var writer = stdin.writer(&.{});
                const writerPtr = &writer.interface;

                while (true) {
                    _ = @constCast(&reader).stream(writerPtr, std.io.Limit.unlimited) catch |err| {
                        switch (err) {
                            std.io.Reader.StreamError.ReadFailed => {
                                return err;
                            },
                            std.io.Reader.StreamError.WriteFailed => {
                                return err;
                            },
                            std.io.Reader.StreamError.EndOfStream => {
                                break;
                            },
                        }
                    };
                }
            }
        },
        else => {},
    }

    if (child.stdout_behavior == .Pipe) {
        try child.collectOutput(allocator, &stdout, &stderr, 50 * 1024);
    }

    const term = try child.wait();
    if (term.Exited != 0) {
        if (child.stderr_behavior == .Pipe) {
            std.debug.print("stderr: {s}", .{stderr.items});
        }

        return errors.Err.NonNilExitCode;
    }

    if (child.stdout_behavior == .Pipe) {
        return try stdout.toOwnedSlice(allocator);
    }

    return null;
}
