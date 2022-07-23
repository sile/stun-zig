const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const stun = @import("../stun.zig");
const Padding = stun.Padding;

pub const AlternateServer = struct {
    const Self = @This();
    const expected_attr_type = 0x8023;

    addr: net.Address,

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }
        _ = allocator;
        _ = value_len; // FIXME: Check EOS

        const addr = try stun.net.decodeAddress(reader);
        return Self{ .addr = addr };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try stun.net.encodeAddress(writer, self.addr);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, 4 + self.addr.getOsSockLen());
    }

    pub fn paddingLen(self: Self) u16 {
        _ = self;
        return 0;
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};

pub const ErrorCode = struct {
    const Self = @This();
    const expected_attr_type = 0x0009;

    allocator: ?Allocator = null,

    code: u16,
    reason_phrase: []u8,
    padding: Padding,

    pub fn new(code: u16, reason_phrase: []u8) Self {
        return .{
            .code = code,
            .reason_phrase = reason_phrase,
            .padding = Padding.fromValueLen(reason_phrase.len),
        };
    }

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }

        const value = try reader.readIntBig(u32);
        const class = value >> 8;
        const number = value & 0xFF;
        const code = @intCast(u16, class * 100 + number);

        var reason_phrase = try allocator.alloc(u8, value_len);
        try reader.readNoEof(reason_phrase);

        const padding = try Padding.decode(reader);

        return Self{
            .allocator = allocator,
            .code = code,
            .reason_phrase = reason_phrase,
            .padding = padding,
        };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        const class: u32 = self.code / 100;
        const number: u32 = self.code % 100;
        try writer.writeIntBig(u32, (class << 8) | number);
        try writer.writeAll(self.reason_phrase);

        try self.padding.encode(writer);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, @sizeOf(u32) + self.reason_phrase.len);
    }

    pub fn paddingLen(self: Self) u16 {
        return self.padding.len;
    }

    pub fn deinit(self: Self) void {
        if (self.allocator) |allocator| {
            allocator.free(self.reason_phrase);
        }
    }
};

pub const Fingerprint = struct {
    const Self = @This();
    const expected_attr_type = 0x8028;

    crc32: u32,

    // FIXME: Add a method to check if the CRC value is correct.

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }
        _ = allocator;
        _ = value_len; // FIXME: Check EOS

        const crc32 = try reader.readIntBig(u32);
        return Self{ .crc32 = crc32 };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try writer.writeIntBig(u32, self.crc32);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @sizeOf(@TypeOf(self.crc32));
    }

    pub fn paddingLen(self: Self) u16 {
        _ = self;
        return 0;
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};

pub const MappedAddress = struct {
    const Self = @This();
    const expected_attr_type = 0x0001;

    addr: net.Address,

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }
        _ = allocator;
        _ = value_len; // FIXME: Check EOS

        const addr = try stun.net.decodeAddress(reader);
        return Self{ .addr = addr };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try stun.net.encodeAddress(writer, self.addr);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, 4 + self.addr.getOsSockLen());
    }

    pub fn paddingLen(self: Self) u16 {
        _ = self;
        return 0;
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};

pub const MessageIntegrity = struct {
    const Self = @This();
    const expected_attr_type = 0x0008;

    hmac_sha1: [20]u8,

    // FIXME: Add methods to generate and check `hmac_sha1` values.

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }
        _ = allocator;
        _ = value_len; // FIXME: Check EOS

        var buf: [20]u8 = undefined;
        try reader.readNoEof(&buf);

        return Self{ .hmac_sha1 = buf };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try writer.writeAll(&self.hmac_sha1);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @sizeOf(@TypeOf(self.hmac_sha1));
    }

    pub fn paddingLen(self: Self) u16 {
        _ = self;
        return 0;
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};

pub const Nonce = struct {
    const Self = @This();
    const expected_attr_type = 0x0015;

    allocator: ?Allocator = null,

    value: []u8,
    padding: Padding,

    pub fn new(value: []u8) Self {
        return .{
            .value = value,
            .padding = Padding.fromValueLen(value.len),
        };
    }

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }

        // FIXME: Add length check.
        var value = try allocator.alloc(u8, value_len);
        try reader.readNoEof(value);
        const padding = try Padding.decode(reader);

        return Self{
            .allocator = allocator,
            .value = value,
            .padding = padding,
        };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try writer.writeAll(self.value);
        try self.padding.encode(writer);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, self.value.len);
    }

    pub fn paddingLen(self: Self) u16 {
        return self.padding.len;
    }

    pub fn deinit(self: Self) void {
        if (self.allocator) |allocator| {
            allocator.free(self.value);
        }
    }
};

pub const Realm = struct {
    const Self = @This();
    const expected_attr_type = 0x0014;

    allocator: ?Allocator = null,

    text: []u8,
    padding: Padding,

    pub fn new(text: []u8) Self {
        return .{
            .text = text,
            .padding = Padding.fromValueLen(text.len),
        };
    }

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }

        // FIXME: Add length check.
        var text = try allocator.alloc(u8, value_len);
        try reader.readNoEof(text);
        const padding = try Padding.decode(reader);

        return Self{
            .allocator = allocator,
            .text = text,
            .padding = padding,
        };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try writer.writeAll(self.text);
        try self.padding.encode(writer);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, self.text.len);
    }

    pub fn paddingLen(self: Self) u16 {
        return self.padding.len;
    }

    pub fn deinit(self: Self) void {
        if (self.allocator) |allocator| {
            allocator.free(self.text);
        }
    }
};

pub const Software = struct {
    const Self = @This();
    const expected_attr_type = 0x8022;

    allocator: ?Allocator = null,

    description: []u8,
    padding: Padding,

    pub fn new(description: []u8) Self {
        return .{
            .description = description,
            .padding = Padding.fromValueLen(description.len),
        };
    }

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }

        // FIXME: Add length check.
        var description = try allocator.alloc(u8, value_len);
        try reader.readNoEof(description);
        const padding = try Padding.decode(reader);

        return Self{
            .allocator = allocator,
            .description = description,
            .padding = padding,
        };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try writer.writeAll(self.description);
        try self.padding.encode(writer);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, self.description.len);
    }

    pub fn paddingLen(self: Self) u16 {
        return self.padding.len;
    }

    pub fn deinit(self: Self) void {
        if (self.allocator) |allocator| {
            allocator.free(self.description);
        }
    }
};

pub const UnknownAttributes = struct {
    const Self = @This();
    const expected_attr_type = 0x000A;

    allocator: ?Allocator = null,

    unknown_attr_types: []u16,
    padding: Padding,

    pub fn new(unknown_attr_types: []u16) Self {
        return .{
            .unknown_attr_types = unknown_attr_types,
            .padding = Padding.fromValueLen(unknown_attr_types.len() * @sizeOf(u16)),
        };
    }

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }
        if (value_len % 2 != 0) {
            return error.InvalidAttributeValueBytes;
        }

        var valueReader = std.io.limitedReader(reader, value_len).reader();
        var list = ArrayList(u16).init(allocator);
        while (true) {
            const v = valueReader.readIntBig(u16) catch |e| {
                switch (e) {
                    error.EndOfStream => {
                        break;
                    },
                    else => {
                        return e;
                    },
                }
            };
            try list.append(v);
        }

        const padding = try Padding.decode(reader);

        return Self{
            .allocator = allocator,
            .unknown_attr_types = list.toOwnedSlice(),
            .padding = padding,
        };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        for (self.unknown_attr_types) |attr_type| {
            try writer.writeIntBig(u16, attr_type);
        }
        try self.padding.encode(writer);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, self.unknown_attr_types.len * @sizeOf(u16));
    }

    pub fn paddingLen(self: Self) u16 {
        return self.padding.len;
    }

    pub fn deinit(self: Self) void {
        if (self.allocator) |allocator| {
            allocator.free(self.unknown_attr_types);
        }
    }
};

pub const Username = struct {
    const Self = @This();
    const expected_attr_type = 0x0006;

    allocator: ?Allocator = null,

    name: []u8,
    padding: Padding,

    pub fn new(name: []u8) Self {
        return .{
            .name = name,
            .padding = Padding.fromValueLen(name.len),
        };
    }

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }

        // FIXME: Add length check.
        var name = try allocator.alloc(u8, value_len);
        try reader.readNoEof(name);
        const padding = try Padding.decode(reader);

        return Self{
            .allocator = allocator,
            .name = name,
            .padding = padding,
        };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try writer.writeAll(self.name);
        try self.padding.encode(writer);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, self.name.len);
    }

    pub fn paddingLen(self: Self) u16 {
        return self.padding.len;
    }

    pub fn deinit(self: Self) void {
        if (self.allocator) |allocator| {
            allocator.free(self.name);
        }
    }
};

pub const XorMappedAddress = struct {
    const Self = @This();
    const expected_attr_type = 0x0020;

    xor_addr: net.Address,

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        if (attr_type != expected_attr_type) {
            return error.AttributeTypeMismatch;
        }
        _ = allocator;
        _ = value_len; // FIXME: Check EOS

        const addr = try stun.net.decodeAddress(reader);
        return Self{ .xor_addr = addr };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try stun.net.encodeAddress(writer, self.xor_addr);
    }

    pub fn canDecode(attr_type: u16) bool {
        return attr_type == expected_attr_type;
    }

    pub fn attrType(self: Self) u16 {
        _ = self;
        return expected_attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, 4 + self.xor_addr.getOsSockLen());
    }

    pub fn paddingLen(self: Self) u16 {
        _ = self;
        return 0;
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};
