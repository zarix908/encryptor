const std = @import("std");
const encrypter = @import("encrypter");

pub fn main() !void {
    const program_path = std.mem.span(std.os.argv[0]);
    const keepassxc_db_path = std.mem.span(std.os.argv[1]);
    const target_filename = std.mem.span(std.os.argv[2]);

    try encrypter.encrypt(program_path, keepassxc_db_path, target_filename);
}
