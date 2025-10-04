const std = @import("std");
const call = @import("call.zig");
const errors = @import("errors.zig");
const ExecPaths = @import("ExecPaths.zig");
const TmpDir = @import("TmpDir.zig");
const libtar = @cImport(@cInclude("libtar.h"));

pub fn encrypt(program_path: []const u8, keepass_db_path: []const u8, target_filepath: []const u8) !void {
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

    const public_key = try generateKey(exec_allocator, small_strings_alloc, execs, keepass_db_path, tmp_dir);
    defer small_strings_alloc.free(public_key);
    std.debug.print("public key: {s}\n", .{public_key});

    const encrypted_filename = try std.mem.join(small_strings_alloc, ".", &.{ target_filename, "age" });
    const encrypted_filepath = try std.fs.path.join(small_strings_alloc, &.{ tmp_dir.path, encrypted_filename });
    defer small_strings_alloc.free(encrypted_filepath);

    try call.call(
        void,
        exec_allocator,
        &.{ execs.age, "-r", public_key, "-o", encrypted_filepath, target_filepath },
        call.Stdin.Ignore,
        std.process.Child.StdIo.Inherit,
    );

    try std.fs.cwd().copyFile(program_path, try std.fs.openDirAbsolute(tmp_dir.getPath(), .{}), "encrypter", .{});

    var tar: *libtar.TAR = undefined;
    libtar.tar_open(tar, pathname: [*c]const u8, @"type": [*c]tartype_t, oflags: c_int, mode: c_int, options: c_int)

    std.debug.print("Completed successfully\n", .{});
}

fn generateKey(
    exec_allocator: std.mem.Allocator,
    small_strings_alloc: std.mem.Allocator,
    execs: ExecPaths,
    keepass_db_path: []const u8,
    tmp_dir: TmpDir,
) ![]const u8 {
    const key_filepath = try std.fs.path.join(small_strings_alloc, &.{ tmp_dir.getPath(), "key.age" });
    defer small_strings_alloc.free(key_filepath);

    try call.call(
        void,
        exec_allocator,
        &.{ execs.keepassxc, "add", "--generate", keepass_db_path, "enc_new" },
        call.Stdin.Inherit,
        std.process.Child.StdIo.Inherit,
    );

    const key = try call.call(
        []u8,
        exec_allocator,
        &.{execs.age_keygen},
        call.Stdin.Ignore,
        std.process.Child.StdIo.Pipe,
    );
    defer exec_allocator.free(key);

    try call.call(
        void,
        exec_allocator,
        &.{
            execs.keepassxc,
            "show",
            "--attributes",
            "password",
            "--show-protected",
            keepass_db_path,
            "enc_new",
        },
        call.Stdin.Inherit,
        std.process.Child.StdIo.Inherit,
    );

    try call.call(
        void,
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

    const public_key_output = try call.call(
        []u8,
        exec_allocator,
        &.{ execs.age_keygen, "-y" },
        call.Stdin{ .PipeBuffer = key },
        std.process.Child.StdIo.Pipe,
    );
    defer exec_allocator.free(public_key_output);

    var public_key_iter = std.mem.splitScalar(
        u8,
        public_key_output,
        '\n',
    );
    const pub_key = public_key_iter.next() orelse return errors.Err.UnexpectedNull;

    const public_key = try small_strings_alloc.alloc(u8, pub_key.len);
    @memmove(public_key, pub_key);

    return public_key;
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
