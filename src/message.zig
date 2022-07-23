const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const stun = @import("stun.zig");
const Method = stun.Method;
const Class = stun.Class;
const TransactionId = stun.TransactionId;

pub const MAGIC_COOKIE: u32 = 0x2112_A442;

pub fn Message(comptime AttributeType: type) type {
    return struct {
        const Self = @This();

        allocator: ?Allocator = null,

        class: Class,
        method: Method,
        transaction_id: TransactionId,
        attributes: []AttributeType,

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
                0b00 => Class.request,
                0b01 => Class.indication,
                0b10 => Class.success_response,
                0b11 => Class.error_response,
                else => unreachable,
            };
            const method = @intCast(
                Method,
                (message_type & 0b0000_0000_1111) | ((message_type >> 1) & 0b0000_0111_0000) | ((message_type >> 2) & 0b1111_1000_0000),
            );

            var attributes = try decodeAttributes(allocator, std.io.limitedReader(reader, message_len).reader());

            return Self{
                .allocator = allocator,
                .class = class,
                .method = method,
                .transaction_id = transaction_id,
                .attributes = attributes.toOwnedSlice(),
            };
        }

        pub fn encode(self: Self, writer: anytype) !void {
            // Header.
            try writer.writeIntBig(u16, self.messageType());
            try writer.writeIntBig(u16, self.messageLen());
            try writer.writeIntBig(u32, MAGIC_COOKIE);
            try writer.writeAll(&self.transaction_id);

            // Attributes.
            for (self.attributes) |attr| {
                try writer.writeIntBig(u16, attr.attrType());
                try writer.writeIntBig(u16, attr.valueLen());
                try attr.encode(writer);
            }
        }

        pub fn deinit(self: Self) void {
            for (self.attributes) |attr| {
                attr.deinit();
            }
            if (self.allocator) |allocator| {
                allocator.free(self.attributes);
            }
        }

        fn messageType(self: Self) u16 {
            const method = @intCast(u16, self.method);
            const class = @intCast(u16, @enumToInt(self.class));
            return (method & 0b0000_0000_1111) | ((class & 0b01) << 4) | ((method & 0b0000_0111_0000) << 5) | ((class & 0b10) << 7) | ((method & 0b1111_1000_0000) << 9);
        }

        fn messageLen(self: Self) u16 {
            var n: u16 = 0;
            for (self.attributes) |attr| {
                n += 4 + attr.valueLen() + attr.paddingLen();
            }
            return n;
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
                // FIXME: Check EOS by just reading one byte (instead of two)
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
                const padding_len = (4 - value_len % 4) % 4;
                const valueAndPaddingReader = std.io.limitedReader(reader, value_len + padding_len).reader();
                const attribute = try AttributeType.decode(allocator, attr_type, valueAndPaddingReader, value_len);
                try attributes.append(attribute);
            }

            return attributes;
        }
    };
}

test "Decode and encode" {
    const bytes = [_]u8{ 0, 1, 0, 8, 33, 18, 164, 66, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 128, 34, 0, 3, 102, 111, 111, 0 };

    // Decode.
    const reader = std.io.fixedBufferStream(&bytes).reader();
    const message = try Message(stun.RawAttribute).decode(std.testing.allocator, reader);
    defer message.deinit();

    // Encode.
    var buf = ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try message.encode(buf.writer());
    try std.testing.expect(std.mem.eql(u8, &bytes, buf.items));
}
