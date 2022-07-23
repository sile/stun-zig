pub const attributes = @import("rfc5389/attributes.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
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

pub const Attribute = stun.UnionAttribute(union(enum) {
    alternate_server: attributes.AlternateServer,
    error_code: attributes.ErrorCode,
    fingerprint: attributes.Fingerprint,
    mapped_address: attributes.MappedAddress,
    message_integrity: attributes.MessageIntegrity,
    nonce: attributes.Nonce,
    realm: attributes.Realm,
    software: attributes.Software,
    unknown_attributes: attributes.UnknownAttributes,
    username: attributes.Username,
    xor_mapped_address: attributes.XorMappedAddress,
    other: stun.RawAttribute,
});
