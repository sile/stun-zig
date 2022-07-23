const std = @import("std");
const Allocator = std.mem.Allocator;
const stun = @import("../stun.zig");
const Padding = stun.Padding;

pub const ErrorCode = struct {
    const Self = @This();

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
        if (attr_type != Self.attrType()) {
            return error.AttributeTypeMismatch;
        }

        const value = try reader.readIntBig(u32);
        const class = value >> 8;
        const number = value & 0xFF;
        const code = @intCast(u16, class * 100 + number);

        const reason_phrase = try reader.readAllAlloc(value_len - @sizeOf(u32));

        const padding = Padding.decode(reader);

        return Self{
            .allocator = allocator,
            .code = code,
            .reason_phrase = reason_phrase,
            .paddig = padding,
        };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        const class: u32 = self.code / 100;
        const number: u32 = self.code % 100;
        try writer.writeIntBig(u32, (class << 8) | number);
        try writer.writeAll(self.reason_phrase);

        try self.padding.encode(writer);
    }

    pub fn attrType() u16 {
        return 0x0009;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, @sizeOf(u32) + self.reason_phrase.len);
    }

    pub fn paddingLen(self: Self) u16 {
        return self.padding.len;
    }

    pub fn deinit(self: Self) !void {
        if (self.allocator) |allocator| {
            allocator.free(self.reason_phrase);
        }
    }
};
