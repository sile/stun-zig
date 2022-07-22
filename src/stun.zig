pub const message = @import("message.zig");
pub const attribute = @import("attribute.zig");

pub const Method = u12;

pub const TransactionId = [12]u8;

test {
    _ = @import("message.zig");
}
