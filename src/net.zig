const std = @import("std");
const net = std.net;
const os = std.os;
const stun = @import("stun.zig");

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

    pub fn addressLen(self: Self) u16 {
        switch (self) {
            .ipv4 => return 4,
            .ipv6 => return 16,
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
    const family = Family.fromAddress(addr);
    try writer.writeIntBig(u8, 0); // unused
    try writer.writeIntBig(u8, @enumToInt(family));
    try writer.writeIntBig(u16, addr.getPort());
    switch (family) {
        .ipv4 => {
            const bytes = @ptrCast(*const [4]u8, &addr.in.sa.addr);
            try writer.writeAll(bytes);
        },
        .ipv6 => {
            const bytes = @ptrCast(*const [16]u8, &addr.in6.sa.addr);
            try writer.writeAll(bytes);
        },
    }
}

pub fn addressBytesLen(addr: net.Address) u16 {
    return 4 + stun.net.Family.fromAddress(addr).addressLen();
}

pub fn xorAddress(addr: net.Address, transaction_id: stun.TransactionId) net.Address {
    const xor_port = addr.getPort() ^ @intCast(u16, (stun.magic_cookie >> 16));
    switch (Family.fromAddress(addr)) {
        .ipv4 => {
            const bytes = @ptrCast(*const [4]u8, &addr.in.sa.addr);
            var xor_addr: [4]u8 = undefined;
            for (bytes) |b, i| {
                xor_addr[i] = b ^ @truncate(u8, stun.magic_cookie >> @intCast(u5, (24 - i * 8)));
            }
            return net.Address.initIp4(xor_addr, xor_port);
        },
        .ipv6 => {
            const bytes = @ptrCast(*const [16]u8, &addr.in6.sa.addr);
            var xor_addr: [16]u8 = undefined;
            for (bytes[0..4]) |b, i| {
                xor_addr[i] = b ^ @truncate(u8, stun.magic_cookie >> @intCast(u5, (24 - i * 8)));
            }
            for (bytes[4..16]) |b, i| {
                xor_addr[4 + i] = b ^ transaction_id[i];
            }
            return net.Address.initIp6(xor_addr, xor_port, 0, 0);
        },
    }
}
