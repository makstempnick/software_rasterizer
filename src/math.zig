const std = @import("std");
const root = @import("root.zig");
const zm = @import("zm");
const utils = @import("utils");

const Vec = zm.Vec;
const Mat = zm.Mat;

pub const quart_rot = half_rot / 2.0;
pub const half_rot = std.math.pi;
pub const full_rot = half_rot * 2.0;

pub const right = zm.f32x4(1, 0, 0, 0);
pub const up = zm.f32x4(0, 1, 0, 0);
pub const forward = zm.f32x4(0, 0, 1, 0);

pub const Line = [2]Vec;
pub const Plane = [2]Vec;
pub const Triangle = [3]Vec;

pub const RGBA = [4]u8;

const Buffer = utils.Buffer;

pub fn lerpColor(a: RGBA, b: RGBA, t: f32) RGBA {
    const temp1 = zm.f32x4(@floatFromInt(a[0]), @floatFromInt(a[1]), @floatFromInt(a[2]), @floatFromInt(a[3]));
    const temp2 = zm.f32x4(@floatFromInt(b[0]), @floatFromInt(b[1]), @floatFromInt(b[2]), @floatFromInt(b[3]));
    const lerped = zm.lerp(temp1, temp2, t);

    return RGBA{ @trunc(lerped[0]), @trunc(lerped[1]), @trunc(lerped[2]), @trunc(lerped[3]) };
}

pub fn remRot(rot: f32) f32 {
    if (rot < 0)
        return full_rot - rot;

    if (rot > full_rot)
        return rot - full_rot;

    return rot;
}
pub fn distToPlane(point: Vec, plane: Plane) f32 {
    const dot = zm.dot3(plane[0], plane[1]);
    return point[0] * plane[1][0] + point[1] * plane[1][1] + point[2] * plane[1][2] - dot[0];
}

pub fn getTriangleFlipped(tri: Triangle) Triangle {
    var new = tri;

    new[0] = tri[2];
    new[2] = tri[0];

    return new;
}
pub fn isTriangleCulled(tri: Triangle, mode: root.CullMode) bool {
    return switch (mode) {
        .Back => zm.dot3(-getTriangleMiddle(tri), getTriangleNormal(tri))[0] < 0,
        .Front => zm.dot3(-getTriangleMiddle(tri), getTriangleNormal(tri))[0] > 0,
        .None => false,
    };
}
pub fn getTriangleMiddle(tri: Triangle) Vec {
    return (tri[0] + tri[1] + tri[2]) / zm.f32x4s(3);
}
pub fn getTriangleNormal(tri: Triangle) Vec {
    const u = tri[1] - tri[0];
    const v = tri[2] - tri[0];

    const x = u[1] * v[2] - u[2] * v[1];
    const y = u[2] * v[0] - u[0] * v[2];
    const z = u[0] * v[1] - u[1] * v[0];

    return zm.normalize3(zm.f32x4(x, y, z, 0));
}
pub fn screenProjTri(in: Triangle) Triangle {
    var new: Triangle = undefined;

    for (0..3) |i|
        new[i] = zm.f32x4((in[i][0] / in[i][3] + 1) / 2, (in[i][1] / in[i][3] + 1) / 2, 0, 1);

    return new;
}

pub fn linePlaneIntersection(line: Line, plane: Plane, t: *Vec) Vec {
    const dot = zm.dot3(plane[0], plane[1]);
    const a = zm.dot3(line[0], plane[1]);
    const b = zm.dot3(line[1], plane[1]);

    t.* = (dot - a) / (b - a);
    const dist = line[1] - line[0];
    const to_intersect = dist * t.*;
    return line[0] + to_intersect;
}

pub fn clipTriangle(in_tri: Triangle, in_tex: Triangle, plane: Plane, out_tris: []Triangle, out_texs: []Triangle) usize {
    var inside_indices: [3]usize = undefined;
    var inside_count: usize = 0;

    var outside_indices: [3]usize = undefined;
    var outside_count: usize = 0;

    for (0..in_tri.len) |i| {
        if (zm.dot3(in_tri[i] - plane[0], plane[1])[0] >= 0) {
            inside_indices[inside_count] = i;
            inside_count += 1;
        } else {
            outside_indices[outside_count] = i;
            outside_count += 1;
        }
    }

    if (inside_count == 0)
        return 0;

    if (inside_count == 3) {
        out_tris[0] = in_tri;
        out_texs[0] = in_tex;
        return 1;
    }

    if (inside_count == 1) {
        var t = zm.f32x4s(0);

        out_tris[0][0] = in_tri[inside_indices[0]];
        out_texs[0][0] = in_tex[inside_indices[0]];

        out_tris[0][1] = linePlaneIntersection(.{ in_tri[inside_indices[0]], in_tri[outside_indices[0]] }, plane, &t);
        out_texs[0][1] = zm.lerp(in_tex[inside_indices[0]], in_tex[outside_indices[0]], t[0]);

        out_tris[0][2] = linePlaneIntersection(.{ in_tri[inside_indices[0]], in_tri[outside_indices[1]] }, plane, &t);
        out_texs[0][2] = zm.lerp(in_tex[inside_indices[0]], in_tex[outside_indices[1]], t[0]);

        return 1;
    }

    if (inside_count == 2) {
        var t = zm.f32x4s(0);

        out_tris[0][0] = in_tri[inside_indices[0]];
        out_texs[0][0] = in_tex[inside_indices[0]];

        out_tris[0][1] = in_tri[inside_indices[1]];
        out_texs[0][1] = in_tex[inside_indices[1]];

        out_tris[0][2] = linePlaneIntersection(.{ in_tri[inside_indices[0]], in_tri[outside_indices[0]] }, plane, &t);
        out_texs[0][2] = zm.lerp(in_tex[inside_indices[0]], in_tex[outside_indices[0]], t[0]);

        //

        out_tris[1][0] = in_tri[inside_indices[1]];
        out_texs[1][0] = in_tex[inside_indices[1]];

        out_tris[1][1] = out_tris[0][2];
        out_texs[1][1] = out_texs[0][2];

        out_tris[1][2] = linePlaneIntersection(.{ in_tri[inside_indices[1]], in_tri[outside_indices[0]] }, plane, &t);
        out_texs[1][2] = zm.lerp(in_tex[inside_indices[1]], in_tex[outside_indices[0]], t[0]);

        return 2;
    }

    return 0;
}

//

pub fn drawLine(buf: Buffer(u8, 4), x0: i32, y0: i32, x1: i32, y1: i32) void {
    if (@abs(x1 - x0) > @abs(y1 - y0)) {
        if (x1 > x0) {
            drawLineH(buf, x0, y0, x1, y1);
        } else {
            drawLineH(buf, x1, y1, x0, y0);
        }
    } else {
        if (y1 > y0) {
            drawLineV(buf, x0, y0, x1, y1);
        } else {
            drawLineV(buf, x1, y1, x0, y0);
        }
    }
}
fn drawLineH(buf: Buffer(u8, 4), x0: i32, y0: i32, x1: i32, y1: i32) void {
    const dx = x1 - x0;
    var dy = y1 - y0;

    var dir: i32 = 1;

    if (dy < 0) {
        dir = -1;
        dy = -dy;
    }

    var p = 2 * dy - dx;
    var y = y0;

    for (0..@intCast(@abs(dx) + 1)) |x| {
        const final_x = x0 + @as(i32, @intCast(x));

        if (final_x > 0 and final_x < buf.width and y > 0 and y < buf.height)
            buf.setPos(@intCast(final_x), @intCast(y), .{ 255, 0, 0, 255 });

        if (p >= 0) {
            y += dir;
            p += 2 * (dy - dx);
        } else {
            p += 2 * dy;
        }
    }
}
fn drawLineV(buf: Buffer(u8, 4), x0: i32, y0: i32, x1: i32, y1: i32) void {
    const dy = y1 - y0;
    var dx = x1 - x0;

    var dir: i32 = 1;

    if (dx < 0) {
        dir = -1;
        dx = -dx;
    }

    var p = 2 * dx - dy;
    var x = x0;

    for (0..@intCast(@abs(dy) + 1)) |y| {
        const final_y = y0 + @as(i32, @intCast(y));

        if (x > 0 and x < buf.width and final_y > 0 and final_y < buf.height)
            buf.setPos(@intCast(x), @intCast(final_y), .{ 255, 0, 0, 255 });

        if (p >= 0) {
            x += dir;
            p += 2 * (dx - dy);
        } else {
            p += 2 * dx;
        }
    }
}
