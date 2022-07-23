const std = @import("std");
const net = std.net;
const os = std.os;

pub const Family = enum(u8) {
    const Self = @This();

    ipv4 = 1,
    ipv6 = 2,

    pub fn fromAddress(addr: net.Address) Self {
        switch (addr.any.family) {
            os.AF.INET => return Self.ipv4,
            os.AF.INET6 => return Self.ipv6,
            else => unreachable,
        }
    }

    pub fn fromInt(v: u8) !Self {
        switch (v) {
            @enumToInt(Self.ipv4) => return Self.ipv4,
            @enumToInt(Self.ipv6) => return Self.ipv6,
            else => return error.UnknownFamily,
        }
    }
};

pub fn decodeAddress(reader: anytype) !net.Address {
    _ = try reader.readIntBig(u8);
    const family = try Family.fromInt(try reader.readIntBig(u8));
    const port = try reader.readIntBig(u16);
    switch (family) {
        .ipv4 => {
            var buf: [4]u8 = undefined;
            try reader.readNoEof(&buf);
            return net.Address.initIp4(buf, port);
        },
        .ipv6 => {
            var buf: [16]u8 = undefined;
            try reader.readNoEof(&buf);
            return net.Address.initIp6(buf, port, 0, 0);
        },
    }
}

pub fn encodeAddress(writer: anytype, addr: net.Address) !void {
    try writer.writeIntBig(u8, 0); // unused
    try writer.writeIntBig(u8, @enumToInt(Family.fromAddress(addr)));
    try writer.writeIntBig(u16, addr.getPort());
    try writer.writeAll(@ptrCast([*]const u8, &addr.any)[0..addr.getOsSockLen()]);
}
