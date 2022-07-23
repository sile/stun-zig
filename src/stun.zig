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
pub const Padding = attribute.Padding;

test {
    _ = @import("message.zig");
}
