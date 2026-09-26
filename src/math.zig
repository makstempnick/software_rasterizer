const std = @import("std");
const zm = @import("zm");

const App = @import("App.zig");
const Camera = @import("Camera.zig");

const Vec = zm.Vec;

pub const quart_rot = half_rot / 2.0;
pub const half_rot = std.math.pi;
pub const full_rot = half_rot * 2.0;

pub const right = zm.f32x4(1, 0, 0, 0);
pub const up = zm.f32x4(0, 1, 0, 0);
pub const forward = zm.f32x4(0, 0, 1, 0);

pub const Line = [2]Vec;
pub const Plane = [2]Vec;
pub const Triangle = [3]Vec;

pub fn remRot(rot: f32) f32 {
    if (rot < 0) {
        return full_rot - rot;
    }

    if (rot > full_rot) {
        return rot - full_rot;
    }

    return rot;
}

pub fn getTriangleMiddle(triangle: Triangle) Vec {
    return (triangle[0] + triangle[1] + triangle[2]) / zm.f32x4s(3);
}
pub fn getTriangleNormal(triangle: Triangle) Vec {
    const u = triangle[1] - triangle[0];
    const v = triangle[2] - triangle[0];

    const x = u[1] * v[2] - u[2] * v[1];
    const y = u[2] * v[0] - u[0] * v[2];
    const z = u[0] * v[1] - u[1] * v[0];

    return zm.normalize3(zm.f32x4(x, y, z, 0));
}
pub fn localCamProjTriangle(triangle: Triangle, aspect: f32, cam: *Camera) Triangle {
    var new: [3]Vec = undefined;

    for (0..3) |i|
        new[i] = cam.localProjVec(aspect, triangle[i]);

    return new;
}
/// accepts an already local cam projected triangle!!!!!!!!!!!
pub fn screenProjTriangle(triangle: Triangle) Triangle {
    var projected = triangle;

    for (0..3) |i| {
        const proj_x = (triangle[i][0] / triangle[i][2] + 1) / 2;
        const proj_y = (triangle[i][1] / triangle[i][2] + 1) / 2;
        const proj_z = 0;

        projected[i] = zm.f32x4(proj_x, proj_y, proj_z, 1);
    }

    return projected;
}
pub fn getTriangleFlipped(triangle: Triangle) Triangle {
    var new = triangle;

    new[0] = triangle[2];
    new[2] = triangle[0];

    return new;
}
pub fn distToPlane(point: Vec, plane: Plane) f32 {
    const dot = zm.dot3(plane[0], plane[1]);
    return point[0] * plane[1][0] + point[1] * plane[1][1] + point[2] * plane[1][2] - dot[0];
}

/// plane pos and normal
pub fn getLinePlaneIntersection(line: Line, plane: Plane) Vec {
    const dot = zm.dot3(plane[0], plane[1]);
    const ad = zm.dot3(line[0], plane[1]);
    const bd = zm.dot3(line[1], plane[1]);
    const t = (dot - ad) / (bd - ad);
    const delta = line[1] - line[0];
    const to_intersect = delta * t;
    return line[0] + to_intersect;
}

pub fn clipTriangleAgainstPlane(in: Triangle, plane: Plane, out: []Triangle) usize {
    var points_inside: [3]Vec = undefined;
    var inside_count: usize = 0;

    var points_outside: [3]Vec = undefined;
    var outside_count: usize = 0;

    const d0 = distToPlane(in[0], plane);
    const d1 = distToPlane(in[1], plane);
    const d2 = distToPlane(in[2], plane);

    if (d0 >= 0) {
        points_inside[inside_count] = in[0];
        inside_count += 1;
    } else {
        points_outside[outside_count] = in[0];
        outside_count += 1;
    }

    if (d1 >= 0) {
        points_inside[inside_count] = in[1];
        inside_count += 1;
    } else {
        points_outside[outside_count] = in[1];
        outside_count += 1;
    }

    if (d2 >= 0) {
        points_inside[inside_count] = in[2];
        inside_count += 1;
    } else {
        points_outside[outside_count] = in[2];
        outside_count += 1;
    }

    if (inside_count == 0)
        return 0;

    if (inside_count == 3) {
        out[0] = in;
        return 1;
    }

    if (inside_count == 1 and outside_count == 2) {
        out[0] = in;

        out[0][0] = points_inside[0];
        out[0][1] = getLinePlaneIntersection(.{ points_inside[0], points_outside[0] }, plane);
        out[0][2] = getLinePlaneIntersection(.{ points_inside[0], points_outside[1] }, plane);

        return 1;
    }

    if (inside_count == 2 and outside_count == 1) {
        out[0] = in;
        out[1] = in;

        out[0][0] = points_inside[0];
        out[0][1] = points_inside[1];
        out[0][2] = getLinePlaneIntersection(.{ points_inside[0], points_outside[0] }, plane);

        out[1][0] = points_inside[1];
        out[1][1] = out[0][2];
        out[1][2] = getLinePlaneIntersection(.{ points_inside[1], points_outside[0] }, plane);

        return 2;
    }

    return 0;
}
