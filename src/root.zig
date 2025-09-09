const std = @import("std");
const call = @import("call.zig");
const errors = @import("errors.zig");

pub fn init() !void {
    const appdir = std.posix.getenv("APPDIR") orelse return errors.Err.AppDirEnvNotFound;
    const keepassxc = "bin/keepassxc-cli";
    const age_keygen = "bin/age-keygen";
    const age = "bin/age";

    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var output = try call.call(
        allocator,
        keepassxc,
        4,
        &.{ "add", "--generate", "/home/user/sync/kdbx/private.kdbx", "cold_keys/enc_new" },
        appdir,
        call.Stdin.Inherit,
        std.process.Child.StdIo.Inherit,
    );
    std.debug.assert(output == null);

    const key = try call.call(
        allocator,
        age_keygen,
        0,
        &.{},
        appdir,
        call.Stdin.Ignore,
        std.process.Child.StdIo.Pipe,
    ) orelse return errors.Err.UnexpectedNull;

    output = try call.call(
        allocator,
        keepassxc,
        6,
        &.{ "show", "--attributes", "password", "--show-protected", "/home/user/sync/kdbx/private.kdbx", "cold_keys/enc_new" },
        appdir,
        call.Stdin.Inherit,
        std.process.Child.StdIo.Inherit,
    );
    std.debug.assert(output == null);

    output = try call.call(
        allocator,
        age,
        3,
        &.{ "--passphrase", "--output", "key.age" },
        appdir,
        call.Stdin{ .Pipe = key },
        std.process.Child.StdIo.Inherit,
    );
    std.debug.assert(output == null);

    std.debug.print("Completed successfully\n", .{});
}
