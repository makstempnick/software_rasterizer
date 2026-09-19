const std = @import("std");
const zm = @import("zm");

const Vec = zm.Vec;
const Camera = @import("Camera.zig");

const Self = @This();

vertices: [3]Vec,

pub fn init(vertices: [3]Vec) Self {
    return .{
        .vertices = vertices,
    };
}
pub fn getMiddle(self: *const Self) Vec {
    return (self.vertices[0] + self.vertices[1] + self.vertices[2]) / zm.f32x4s(3);
}
pub fn getNormal(self: *const Self) Vec {
    const u = self.vertices[1] - self.vertices[0];
    const v = self.vertices[2] - self.vertices[0];

    const x = u[1] * v[2] - u[2] * v[1];
    const y = u[2] * v[0] - u[0] * v[2];
    const z = u[0] * v[1] - u[1] * v[0];

    return zm.normalize3(zm.f32x4(x, y, z, 0));
}
pub fn localCamProj(self: *const Self, aspect: f32, cam: *Camera) Self {
    var vertices: [3]Vec = undefined;

    for (0..3) |i|
        vertices[i] = cam.localProjVec(aspect, self.vertices[i]);

    return .{
        .vertices = vertices,
    };
}
pub fn getFlipped(self: *const Self) Self {
    var vertices = self.vertices;

    vertices[0] = self.vertices[2];
    vertices[2] = self.vertices[0];

    return .{
        .vertices = vertices,
    };
}
