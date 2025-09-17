const std = @import("std");
const call = @import("call.zig");
const errors = @import("errors.zig");
const ExecPaths = @import("ExecPaths.zig");
const TmpDir = @import("TmpDir.zig");

pub fn encrypt(keepass_db_path: []const u8, target_filepath: []const u8) !void {
    const max_string_len = 4096;
    var buffer: [max_string_len * 64]u8 = undefined; // assume that less than 64 strings will be allocated
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const small_strings_alloc = fba.allocator();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const exec_allocator = gpa.allocator();

    // paths to all executables that will be called
    var execs = try buildExecPaths(small_strings_alloc);
    defer execs.deinit(small_strings_alloc);

    const target_filename = std.fs.path.basename(target_filepath); // target - file that will be encrypted
    var tmp_dir = try TmpDir.create(small_strings_alloc, target_filename);
    defer tmp_dir.clear(small_strings_alloc) catch {};

    try generateKey(exec_allocator, small_strings_alloc, execs, keepass_db_path, tmp_dir);

    std.debug.print("Completed successfully\n", .{});
}

fn generateKey(
    exec_allocator: std.mem.Allocator,
    small_strings_alloc: std.mem.Allocator,
    execs: ExecPaths,
    keepass_db_path: []const u8,
    tmp_dir: TmpDir,
) !void {
    const key_filepath = try std.fs.path.join(small_strings_alloc, &.{ tmp_dir.getPath(), "key.age" });
    defer small_strings_alloc.free(key_filepath);

    var output = try call.call(
        exec_allocator,
        &.{ execs.keepassxc, "add", "--generate", keepass_db_path, "cold_keys/enc_new" },
        call.Stdin.Inherit,
        std.process.Child.StdIo.Inherit,
    );
    std.debug.assert(output == null);

    const key = try call.call(
        exec_allocator,
        &.{execs.age_keygen},
        call.Stdin.Ignore,
        std.process.Child.StdIo.Pipe,
    ) orelse return errors.Err.UnexpectedNull;
    defer exec_allocator.free(key);

    output = try call.call(
        exec_allocator,
        &.{
            execs.keepassxc,
            "show",
            "--attributes",
            "password",
            "--show-protected",
            keepass_db_path,
            "cold_keys/enc_new",
        },
        call.Stdin.Inherit,
        std.process.Child.StdIo.Inherit,
    );
    std.debug.assert(output == null);

    output = try call.call(
        exec_allocator,
        &.{
            execs.age,
            "--passphrase",
            "--output",
            key_filepath,
        },
        call.Stdin{ .PipeBuffer = key },
        std.process.Child.StdIo.Inherit,
    );
    std.debug.assert(output == null);
}

fn buildExecPaths(allocator: std.mem.Allocator) !ExecPaths {
    const appdir = std.posix.getenv("APPDIR") orelse return errors.Err.AppDirEnvNotFound;
    const testenv = std.posix.getenv("TEST");

    var bin_subdir: []const u8 = "usr/bin";
    if (testenv) |is_test| {
        if (std.mem.eql(u8, is_test, "1")) {
            bin_subdir = "build_bin";
        }
    }

    return ExecPaths.init(allocator, appdir, bin_subdir);
}
