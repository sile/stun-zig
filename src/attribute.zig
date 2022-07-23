const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const RawAttribute = struct {
    const Self = @This();

    allocator: ?Allocator = null,

    attr_type: u16,
    value: []u8,
    padding: Padding,

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
        var value = try allocator.alloc(u8, value_len);
        try reader.readNoEof(value);
        const padding = try Padding.decode(reader);
        return Self{
            .allocator = allocator,
            .attr_type = attr_type,
            .value = value,
            .padding = padding,
        };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try writer.writeAll(self.value);
        try self.padding.encode(writer);
    }

    pub fn canDecode(attr_type: u16) bool {
        _ = attr_type;
        return true;
    }

    pub fn attrType(self: Self) u16 {
        return self.attr_type;
    }

    pub fn valueLen(self: Self) u16 {
        return @intCast(u16, self.value.len);
    }

    pub fn paddingLen(self: Self) u16 {
        return self.padding.len;
    }

    pub fn deinit(self: Self) void {
        if (self.allocator) |allocator| {
            allocator.free(self.value);
        }
    }
};

pub fn UnionAttribute(comptime T: type) type {
    return struct {
        const Self = @This();

        attr: T,

        pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype, value_len: u16) !Self {
            switch (@typeInfo(T)) {
                .Union => |attrs| {
                    if (attrs.tag_type == null) {
                        @panic("not a tagged union");
                    }

                    inline for (attrs.fields) |field| {
                        if (field.field_type.canDecode(attr_type)) {
                            const attr = try field.field_type.decode(
                                allocator,
                                attr_type,
                                reader,
                                value_len,
                            );
                            return Self{ .attr = @unionInit(T, field.name, attr) };
                        }
                    }
                },
                else => @panic("not a union type"),
            }

            return error.UnexpectedAttributeType;
        }

        pub fn encode(self: Self, writer: anytype) !void {
            switch (@typeInfo(T)) {
                .Union => |attrs| {
                    const tag_type = attrs.tag_type orelse @panic("not a tagged union");
                    switch (@typeInfo(tag_type)) {
                        .Enum => |enum_info| {
                            inline for (enum_info.fields) |field| {
                                if (field.value == @enumToInt(self.attr)) {
                                    try @field(self.attr, field.name).encode(writer);
                                    return;
                                }
                            }
                        },
                        else => unreachable,
                    }
                },
                else => @panic("not a union type"),
            }
        }

        pub fn attrType(self: Self) u16 {
            switch (@typeInfo(T)) {
                .Union => |attrs| {
                    const tag_type = attrs.tag_type orelse @panic("not a tagged union");
                    switch (@typeInfo(tag_type)) {
                        .Enum => |enum_info| {
                            inline for (enum_info.fields) |field| {
                                if (field.value == @enumToInt(self.attr)) {
                                    return @field(self.attr, field.name).attrType();
                                }
                            }
                            unreachable;
                        },
                        else => unreachable,
                    }
                },
                else => @panic("not a union type"),
            }
        }

        pub fn valueLen(self: Self) u16 {
            switch (@typeInfo(T)) {
                .Union => |attrs| {
                    const tag_type = attrs.tag_type orelse @panic("not a tagged union");
                    switch (@typeInfo(tag_type)) {
                        .Enum => |enum_info| {
                            inline for (enum_info.fields) |field| {
                                if (field.value == @enumToInt(self.attr)) {
                                    return @field(self.attr, field.name).valueLen();
                                }
                            }
                            unreachable;
                        },
                        else => unreachable,
                    }
                },
                else => @panic("not a union type"),
            }
        }

        pub fn paddingLen(self: Self) u16 {
            switch (@typeInfo(T)) {
                .Union => |attrs| {
                    const tag_type = attrs.tag_type orelse @panic("not a tagged union");
                    switch (@typeInfo(tag_type)) {
                        .Enum => |enum_info| {
                            inline for (enum_info.fields) |field| {
                                if (field.value == @enumToInt(self.attr)) {
                                    return @field(self.attr, field.name).paddingLen();
                                }
                            }
                            unreachable;
                        },
                        else => unreachable,
                    }
                },
                else => @panic("not a union type"),
            }
        }

        pub fn deinit(self: Self) void {
            switch (@typeInfo(T)) {
                .Union => |attrs| {
                    const tag_type = attrs.tag_type orelse @panic("not a tagged union");
                    switch (@typeInfo(tag_type)) {
                        .Enum => |enum_info| {
                            inline for (enum_info.fields) |field| {
                                if (field.value == @enumToInt(self.attr)) {
                                    @field(self.attr, field.name).deinit();
                                    return;
                                }
                            }
                        },
                        else => unreachable,
                    }
                },
                else => @panic("not a union type"),
            }
        }
    };
}

pub const Padding = struct {
    const Self = @This();

    data: [4]u8,
    len: u2,

    pub fn new(padding: []u8) !Self {
        if (padding.len > 3) {
            return error.TooLargePaddingBytes;
        }

        var data: [4]u8 = undefined;
        for (padding) |b, i| {
            data[i] = b;
        }

        return Self{
            .data = data,
            .len = @intCast(u2, data.len),
        };
    }

    pub fn fromValueLen(value_len: usize) Self {
        const len = (4 - value_len % 4) % 4;
        return .{ .data = .{ 0, 0, 0, 0 }, .len = len };
    }

    pub fn decode(reader: anytype) !Self {
        var data: [4]u8 = undefined;
        const len = try reader.readAll(&data);
        if (len == 4) {
            return error.TooLargePaddingBytes;
        }
        return Self{
            .data = data,
            .len = @intCast(u2, len),
        };
    }

    pub fn encode(self: Self, writer: anytype) !void {
        try writer.writeAll(self.data[0..self.len]);
    }
};
