const std = @import("std");

pub const Opcode = u8;

pub const PacketType = enum(u2) {
    Fixed = 0,
    Variable1 = 1,
    Variable2 = 2,
};

pub const PacketInfo = packed struct {
    opcode: Opcode,
    packet_type: PacketType,
    length: ?u16, // null for variable-length packets
};

pub const PacketHandler = struct {
    allocator: std.mem.Allocator,
    packet_info: std.AutoHashMap(Opcode, PacketInfo),

    pub fn init(allocator: std.mem.Allocator) PacketHandler {
        return .{
            .allocator = allocator,
            .packet_info = std.AutoHashMap(Opcode, PacketInfo).init(allocator),
        };
    }

    pub fn deinit(self: *PacketHandler) void {
        self.packet_info.deinit();
    }

    pub fn registerPacket(self: *PacketHandler, info: PacketInfo) !void {
        try self.packet_info.put(info.opcode, info);
    }
};

pub fn encodePacket(allocator: std.mem.Allocator, handler: *PacketHandler, opcode: Opcode, data: []const u8) ![]u8 {
    const info = handler.packet_info.get(opcode) orelse return error.UnknownOpcode;
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append(opcode);

    switch (info.packet_type) {
        .Fixed => {},
        .Variable1 => try buffer.append(data.len & 0xFF),
        .Variable2 => try buffer.appendSlice(data.len & 0xFFFF),
    }

    try buffer.appendSlice(data);
    return buffer.toOwnedSlice();
}

pub fn decodePacket(handler: *PacketHandler, packet: []const u8) !struct { opcode: Opcode, data: []const u8 } {
    if (packet.len == 0) return error.EmptyPacket;

    const opcode = packet[0];
    const info = handler.packet_info.get(opcode) orelse return error.UnknownOpcode;

    var data_start: usize = 1;
    var data_length: usize = undefined;

    switch (info.packet_type) {
        .Fixed => data_length = info.length.?,
        .Variable1 => {
            if (packet.len < 2) return error.InvalidPacket;
            data_length = packet[1];
            data_start = 2;
        },
        .Variable2 => {
            if (packet.len < 3) return error.InvalidPacket;
            data_length = std.mem.readIntSliceBig(u16, packet[1..3]);
            data_start = 3;
        },
    }

    if (packet.len < data_start + data_length) return error.InvalidPacket;

    return .{
        .opcode = opcode,
        .data = packet[data_start .. data_start + data_length],
    };
}

pub const ClientPackets = struct {
    handler: PacketHandler,

    pub fn init(allocator: std.mem.Allocator) !ClientPackets {
        var self = ClientPackets{
            .handler = PacketHandler.init(allocator),
        };
        try self.registerPackets();
        return self;
    }

    pub fn deinit(self: *ClientPackets) void {
        self.handler.deinit();
    }

    fn registerPackets(self: *ClientPackets) !void {
        try self.handler.registerPacket(.{ .opcode = 1, .packet_type = .Fixed, .length = 10 });
        try self.handler.registerPacket(.{ .opcode = 2, .packet_type = .Variable1, .length = null });
        try self.handler.registerPacket(.{ .opcode = 3, .packet_type = .Variable2, .length = null });
    }
};

pub const ServerPackets = struct {
    handler: PacketHandler,

    pub fn init(allocator: std.mem.Allocator) !ServerPackets {
        var self = ServerPackets{
            .handler = PacketHandler.init(allocator),
        };
        try self.registerPackets();
        return self;
    }

    pub fn deinit(self: *ServerPackets) void {
        self.handler.deinit();
    }

    fn registerPackets(self: *ServerPackets) !void {
        try self.handler.registerPacket(.{ .opcode = 1, .packet_type = .Fixed, .length = 5 });
        try self.handler.registerPacket(.{ .opcode = 2, .packet_type = .Variable1, .length = null });
        try self.handler.registerPacket(.{ .opcode = 3, .packet_type = .Variable2, .length = null });
    }
};
