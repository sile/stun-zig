pub const net = @import("net.zig");
pub const rfc5389 = @import("rfc5389.zig");

const std = @import("std");
const message = @import("message.zig");
const attribute = @import("attribute.zig");

pub const Class = enum(u2) {
    request = 0b00,
    indication = 0b01,
    success_response = 0b10,
    error_response = 0b11,
};
pub const Method = u12;
pub const TransactionId = [12]u8;
pub const Message = message.Message;
pub const RawAttribute = attribute.RawAttribute;
pub const UnionAttribute = attribute.UnionAttribute;
pub const Padding = attribute.Padding;

test {
    _ = @import("message.zig");
}

test "Decode and encode" {
    const bytes = [_]u8{ 0, 1, 0, 8, 33, 18, 164, 66, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 128, 34, 0, 3, 102, 111, 111, 0 };

    const TestMessage = Message(rfc5389.Attribute);

    // Decode.
    const reader = std.io.fixedBufferStream(&bytes).reader();
    const msg = try TestMessage.decode(std.testing.allocator, reader);
    defer msg.deinit();

    var found = false;
    for (msg.attributes) |attr| {
        switch (attr.attr) {
            .software => |software| {
                found = true;
                try std.testing.expect(std.mem.eql(u8, software.description, "foo"));
            },
            else => {},
        }
    }

    // Encode.
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try msg.encode(buf.writer());
    try std.testing.expect(std.mem.eql(u8, &bytes, buf.items));
}
