const std = @import("std");
const fs = std.fs;
const UserData = @import("user_data.zig").UserData;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try fs.cwd().openFile("login.bin", .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, 1024 * 1024); // 1MB limit
    defer allocator.free(file_contents);

    var user_data = try UserData.fromBytes(allocator, file_contents);
    defer user_data.deinit(allocator);

    // Print the parsed data
    std.debug.print("Checksums: {any}\n", .{user_data.checksums});
    std.debug.print("UID: {}\n", .{user_data.uid});
    std.debug.print("Username: {s}\n", .{user_data.username});
    std.debug.print("Password: {s}\n", .{user_data.password});
}
