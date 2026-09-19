const std = @import("std");
const zm = @import("zm");

const Vec = zm.Vec;

const Self = @This();

vertices: [3]Vec,

pub fn init(vertices: [3]Vec) Self {
    return .{
        .vertices = vertices,
    };
}
