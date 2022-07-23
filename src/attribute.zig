const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const RawAttribute = struct {
    const Self = @This();

    allocator: ?Allocator = null,

    attr_type: u16,
    attr_data: []u8,

    pub fn decode(allocator: Allocator, attr_type: u16, reader: anytype) !Self {
        const attr_data = try reader.readAllAlloc(allocator, std.math.maxInt(u16));
        return Self{
            .allocator = allocator,
            .attr_type = attr_type,
            .attr_data = attr_data,
        };
    }

    pub fn deinit(self: Self) void {
        if (self.allocator) |allocator| {
            allocator.free(self.attr_data);
        }
    }
};
