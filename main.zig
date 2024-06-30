const std = @import("std");
const fs = std.fs;
const testing = std.testing;

pub const UserData = struct {
    checksums: [4]i32,
    uid: i32,
    username: []u8,
    password: []u8,

    pub fn fromBytes(allocator: std.mem.Allocator, data: []const u8) !UserData {
        if (data.len < 20) {
            return error.InsufficientData;
        }

        var result = UserData{
            .checksums = undefined,
            .uid = undefined,
            .username = undefined,
            .password = undefined,
        };

        // Read checksums
        for (0..4) |i| {
            result.checksums[i] = std.mem.readInt(i32, data[i * 4 ..][0..4], .big);
        }

        // Read UID
        result.uid = std.mem.readInt(i32, data[16..20], .big);

        // Find and allocate username and password
        var current_pos: usize = 20;
        var field_start: usize = current_pos;
        var found_username = false;

        while (current_pos < data.len) : (current_pos += 1) {
            if (data[current_pos] == '\n') {
                if (!found_username) {
                    result.username = try allocator.dupe(u8, data[field_start..current_pos]);
                    found_username = true;
                    field_start = current_pos + 1;
                } else {
                    result.password = try allocator.dupe(u8, data[field_start..current_pos]);
                    return result;
                }
            }
        }

        // If we get here, we didn't find both fields
        // if (result.username) |username| allocator.free(username);
        return error.InvalidFormat;
    }

    pub fn deinit(self: *UserData, allocator: std.mem.Allocator) void {
        allocator.free(self.username);
        allocator.free(self.password);
    }
};

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

test "UserData.fromBytes with sample data" {
    const sample_data = [_]u8{
        0x00, 0x00, 0x00, 0x01, // checksum 1
        0x00, 0x00, 0x00, 0x02, // checksum 2
        0x00, 0x00, 0x00, 0x03, // checksum 3
        0x00, 0x00, 0x00, 0x04, // checksum 4
        0x00, 0x00, 0x00, 0x2A, // uid (42)
        't', 'e', 's', 't', 'u', 's', 'e', 'r', 0x0A, // username "testuser\n"
        'p', 'a', 's', 's', 'w', 'o', 'r', 'd', 0x0A, // password "password\n"
    };

    var user_data = try UserData.fromBytes(testing.allocator, &sample_data);
    defer user_data.deinit(testing.allocator);

    // Test checksums
    try testing.expectEqual([4]i32{ 1, 2, 3, 4 }, user_data.checksums);

    // Test UID
    try testing.expectEqual(@as(i32, 42), user_data.uid);

    // Test username
    try testing.expectEqualStrings("testuser", user_data.username);

    // Test password
    try testing.expectEqualStrings("password", user_data.password);
}
