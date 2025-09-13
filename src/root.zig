const std = @import("std");
const call = @import("call.zig");
const errors = @import("errors.zig");

pub fn encrypt() !void {
    const appdir = std.posix.getenv("APPDIR") orelse return errors.Err.AppDirEnvNotFound;
    const keepassxc = "usr/bin/keepassxc-cli";
    const age_keygen = "usr/bin/age-keygen";
    const age = "usr/bin/age";

    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var output = try call.call(4, .{
        .path_allocator = allocator,
        .executable = keepassxc,
        .cmd_args = &.{ "add", "--generate", "/home/user/sync/kdbx/private.kdbx", "cold_keys/enc_new" },
        .appdir = appdir,
        .input = call.Stdin.Inherit,
        .output = std.process.Child.StdIo.Inherit,
    });
    std.debug.assert(output == null);

    const key = try call.call(0, .{
        .path_allocator = allocator,
        .executable = age_keygen,
        .cmd_args = &.{},
        .appdir = appdir,
        .input = call.Stdin.Ignore,
        .output = std.process.Child.StdIo.Pipe,
    }) orelse return errors.Err.UnexpectedNull;

    output = try call.call(6, .{
        .path_allocator = allocator,
        .executable = keepassxc,
        .cmd_args = &.{ "show", "--attributes", "password", "--show-protected", "/home/user/sync/kdbx/private.kdbx", "cold_keys/enc_new" },
        .appdir = appdir,
        .input = call.Stdin.Inherit,
        .output = std.process.Child.StdIo.Inherit,
    });
    std.debug.assert(output == null);

    output = try call.call(3, .{
        .path_allocator = allocator,
        .executable = age,
        .cmd_args = &.{ "--passphrase", "--output", "build/key.age" },
        .appdir = appdir,
        .input = call.Stdin{ .Pipe = key },
        .output = std.process.Child.StdIo.Inherit,
    });
    std.debug.assert(output == null);

    std.debug.print("Completed successfully\n", .{});
}
