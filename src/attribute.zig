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
        const valueReader = std.io.limitedReader(reader, value_len).reader();
        const value = try valueReader.readAllAlloc(allocator, std.math.maxInt(u16));
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
