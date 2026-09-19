const std = @import("std");
const zm = @import("zm");

const Allocator = std.mem.Allocator;
const Vec = zm.Vec;
const Triangle = @import("Triangle.zig");

const Self = @This();

triangles: []Triangle,

pub fn init(triangles: []Triangle) Self {
    return .{
        .triangles = triangles,
    };
}
pub fn deinit(self: *Self, gpa: Allocator) void {
    gpa.free(self.triangles);
}
