const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const stun = @import("stun.zig");
const Method = stun.Method;
const TransactionId = stun.TransactionId;

pub const MAGIC_COOKIE: u32 = 0x2112_A442;

pub const MessageClass = enum(u4) {
    request = 0b00,
    indication = 0b01,
    success_response = 0b10,
    error_response = 0b11,
};

pub fn Message(comptime AttributeType: type) type {
    return struct {
        const Self = @This();

        class: MessageClass,

        method: Method,

        transaction_id: TransactionId,

        attributes: ArrayList(AttributeType),

        pub fn decode(allocator: Allocator, reader: anytype) !Self {
            const message_type = try reader.readIntBig(u16);
            const message_len = try reader.readIntBig(u16);
            const magic_cookie = try reader.readIntBig(u32);
            if (magic_cookie != MAGIC_COOKIE) {
                return error.MagicCookieMismatch;
            }

            const transaction_id = try reader.readBytesNoEof(@sizeOf(TransactionId));

            if ((message_type >> 14) != 0) {
                return error.FirstTwoBitsOfStunMessageMustBeZero;
            }
            const class = switch (((message_type >> 4) & 0b01) | ((message_type >> 7) & 0b10)) {
                0b00 => MessageClass.request,
                0b01 => MessageClass.indication,
                0b10 => MessageClass.success_response,
                0b11 => MessageClass.error_response,
                else => unreachable,
            };
            const method = @intCast(
                Method,
                (message_type & 0b0000_0000_1111) | ((message_type >> 1) & 0b0000_0111_0000) | ((message_type >> 2) & 0b1111_1000_0000),
            );

            const attributes = try decodeAttributes(allocator, std.io.limitedReader(reader, message_len).reader());

            return Self{
                .class = class,
                .method = method,
                .transaction_id = transaction_id,
                .attributes = attributes,
            };
        }

        pub fn deinit(self: Self) void {
            for (self.attributes.items) |a| {
                a.deinit();
            }
            self.attributes.deinit();
        }

        fn decodeAttributes(allocator: Allocator, reader: anytype) !ArrayList(AttributeType) {
            var attributes = ArrayList(AttributeType).init(allocator);
            errdefer {
                for (attributes.items) |a| {
                    a.deinit();
                }
                attributes.deinit();
            }

            while (true) {
                const attr_type = reader.readIntBig(u16) catch |e| {
                    switch (e) {
                        error.EndOfStream => {
                            break;
                        },
                        else => {
                            return e;
                        },
                    }
                };
                const value_len = try reader.readIntBig(u16);
                const valueReader = std.io.limitedReader(reader, value_len).reader();
                const attribute = try AttributeType.decode(allocator, attr_type, valueReader);
                try attributes.append(attribute);
            }

            var buf: [1]u8 = undefined;
            if ((try reader.readAll(&buf)) != 0) {
                return error.UnconsumedAttributesBytes;
            }

            return attributes;
        }
    };
}

fn tt(comptime T: type) type {
    return T;
}

pub const Foo = struct {
    const Self = @This();

    attr_type: u16,

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype) !Self {
        var buf: [512]u8 = undefined;
        _ = try reader.readAll(&buf);
        _ = allocator;
        return Self{ .attr_type = attr_type };
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};

test "decode" {
    const input = [_]u8{ 0, 1, 0, 8, 33, 18, 164, 66, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 128, 34, 0, 3, 102, 111, 111, 0 };
    const reader = std.io.fixedBufferStream(&input).reader();
    const message = try Message(Foo).decode(std.testing.allocator, reader);
    defer message.deinit();
}
