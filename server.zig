const std = @import("std");
const net = std.net;
const UserData = @import("user_data.zig").UserData;

const ServerConfig = struct {
    port: u16 = 8080,
    max_connections: u32 = 1000,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = ServerConfig{};

    var server = try TcpServer.init(allocator, config);
    // defer server.deinit();

    // try server.listen();
    std.debug.print("Server listening on port {}\n", .{config.port});

    try server.run();
}

const TcpServer = struct {
    allocator: std.mem.Allocator,
    config: ServerConfig,
    address: net.Address,

    pub fn init(allocator: std.mem.Allocator, config: ServerConfig) !TcpServer {
        const address = try net.Address.parseIp("0.0.0.0", config.port);
        return TcpServer{
            .allocator = allocator,
            .config = config,
            .address = address,
        };
    }

    // pub fn deinit(self: *TcpServer) void {
    //     // Nothing to deinit in this case
    // }

    // pub fn listen(self: *TcpServer) !void {
    //     // Nothing to do here, as we'll create the listener in run()
    // }

    pub fn run(self: *TcpServer) !void {
        var listener = try self.address.listen(.{});
        defer listener.deinit();

        while (true) {
            const connection = try listener.accept();
            var thread = try std.Thread.spawn(.{}, handleConnection, .{ self.allocator, connection });
            defer thread.join();
        }
    }
};

fn handleConnection(allocator: std.mem.Allocator, connection: net.Server.Connection) !void {
    const stream = connection.stream;
    defer stream.close();

    var buffer: [1024]u8 = undefined;
    const bytes_read = try stream.read(&buffer);

    if (bytes_read == 0) {
        return;
    }

    var user_data = UserData.fromBytes(allocator, buffer[0..bytes_read]) catch |err| {
        std.debug.print("Error parsing UserData: {}\n", .{err});
        return;
    };
    defer user_data.deinit(allocator);

    std.debug.print("Received UserData:\n", .{});
    std.debug.print("Checksums: {any}\n", .{user_data.checksums});
    std.debug.print("UID: {}\n", .{user_data.uid});
    std.debug.print("Username: {s}\n", .{user_data.username});
    std.debug.print("Password: {s}\n", .{user_data.password});

    // Echo the data back to the client
    const response = try user_data.toBytes(allocator);
    defer allocator.free(response);
    _ = try stream.write(response);
}
