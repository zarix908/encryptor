const std = @import("std");
const encrypter = @import("encrypter");

pub fn main() !void {
    const keepassxc_db_path = std.mem.span(std.os.argv[1]);
    const target_filename = std.mem.span(std.os.argv[2]);

    try encrypter.encrypt(keepassxc_db_path, target_filename);
}
