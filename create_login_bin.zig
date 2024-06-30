const std = @import("std");
const fs = std.fs;
const UserData = @import("user_data.zig").UserData;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const username = try allocator.dupe(u8, "testuser");
    const password = try allocator.dupe(u8, "password");

    var user_data = UserData{
        .checksums = .{ 1, 2, 3, 4 },
        .uid = 42,
        .username = username,
        .password = password,
    };
    defer user_data.deinit(allocator);

    const binary_data = try user_data.toBytes(allocator);
    defer allocator.free(binary_data);

    const file = try fs.cwd().createFile("login.bin", .{ .read = true });
    defer file.close();

    try file.writeAll(binary_data);

    std.debug.print("login.bin file created successfully.\n", .{});
}
