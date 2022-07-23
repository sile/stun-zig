pub const attributes = @import("rfc5389/attributes.zig");

const stun = @import("stun.zig");
const ErrorCode = attributes.ErrorCode;

pub const methods = struct {
    pub const binding: stun.Method = 0x0001;
};

pub const errors = struct {
    pub const try_alternate = ErrorCode.new(300, "Try Alternate");
    pub const bad_request = ErrorCode.new(400, "Bad Request");
    pub const unathorized = ErrorCode.new(401, "Unauthorized");
    pub const unknown_attribute = ErrorCode.new(420, "Unknown Attribute");
    pub const stale_nonce = ErrorCode.new(438, "Stale Nonce");
    pub const server_error = ErrorCode.new(500, "Server Error");
};

pub const AttributeType = enum(u16) {
    error_code = ErrorCode.attrType(),
};

pub const Attribute = union(AttributeType) {
    error_code: ErrorCode,
};

pub fn UnionAttribute(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Union => {},
        else => @panic("not a union type"),
    }

    return struct {};
}
