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

pub const AttributeType = enum(u16) {
    error_code = ErrorCode.attrType(),
};

pub const Attribute = union(AttributeType) {
    error_code: ErrorCode,
};

pub fn UnionAttribute(comptime T: type) type {
    return struct {
        const Self = @This();

        attr: T,

        pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
            switch (@typeInfo(T)) {
                .Union => |attrs| {
                    if (attrs.tag_type) |tag_type| {
                        switch (@typeInfo(tag_type)) {
                            .Enum => |tag| {
                                inline for (tag.fields) |field, i| {
                                    const field_type = attrs.fields[i].field_type;
                                    if (field.value == attr_type) { // canHandle()
                                        const attr = try field_type.decode(
                                            allocator,
                                            attr_type,
                                            reader,
                                            value_len,
                                        );
                                        return Self{ .attr = @unionInit(T, attrs.fields[i].name, attr) };
                                    }
                                }
                            },
                            else => {
                                unreachable;
                            },
                        }
                    } else {
                        @panic("not a tagged union type");
                    }
                },
                else => @panic("not a union type"),
            }

            return error.UnexpectedAttributeType;
        }

        pub fn encode(self: Self, writer: anytype) !void {
            _ = self;
            _ = writer;
            unreachable;
        }

        pub fn attrType(self: Self) u16 {
            _ = self;
            unreachable;
        }

        pub fn valueLen(self: Self) u16 {
            _ = self;
            unreachable;
        }

        pub fn paddingLen(self: Self) u16 {
            _ = self;
            unreachable;
        }

        pub fn deinit(self: Self) void {
            _ = self;
        }
    };
}
