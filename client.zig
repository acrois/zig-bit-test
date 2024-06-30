const std = @import("std");
const net = std.net;
const UserData = @import("user_data.zig").UserData;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try net.Address.parseIp("127.0.0.1", 8080);
    var stream = try net.tcpConnectToAddress(address);
    defer stream.close();

    const username = try allocator.dupe(u8, "testuser");
    defer allocator.free(username);
    const password = try allocator.dupe(u8, "password");
    defer allocator.free(password);

    var user_data = UserData{
        .checksums = .{ 1, 2, 3, 4 },
        .uid = 42,
        .username = username,
        .password = password,
    };

    const data = try user_data.toBytes(allocator);
    defer allocator.free(data);

    _ = try stream.write(data);

    var buffer: [1024]u8 = undefined;
    const bytes_read = try stream.read(&buffer);

    if (bytes_read > 0) {
        var response = try UserData.fromBytes(allocator, buffer[0..bytes_read]);
        defer response.deinit(allocator);

        std.debug.print("Server response:\n", .{});
        std.debug.print("Checksums: {any}\n", .{response.checksums});
        std.debug.print("UID: {}\n", .{response.uid});
        std.debug.print("Username: {s}\n", .{response.username});
        std.debug.print("Password: {s}\n", .{response.password});
    }
}
