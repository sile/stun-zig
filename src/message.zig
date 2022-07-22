const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const stun = @import("stun.zig");
const Method = stun.Method;
const TransactionId = stun.TransactionId;

pub const MessageClass = enum(u4) {
    request = 0b00,
    indication = 0b01,
    success_response = 0b10,
    error_response = 0b11,
};

pub fn Message(comptime AttributeType: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,

        class: MessageClass,

        method: Method,

        transaction_id: TransactionId,

        attributes: ArrayList(AttributeType),

        pub fn decode(allocator: Allocator, reader: anytype) MessageDecodeError!Self {
            _ = allocator;
            _ = reader;
            unreachable;
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.attributes);
        }
    };
}

pub const MessageDecodeError = error{};

test "decode" {
    const input = [_]u8{ 0, 1, 0, 8, 33, 18, 164, 66, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 128, 34, 0, 3, 102, 111, 111, 0 };
    _ = try Message(u8).decode(std.testing.allocator, &input);
}
