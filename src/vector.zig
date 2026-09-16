const std = @import("std");

pub const Vec3f = [3]f32;
pub const Vec2f = [2]f32;

pub const AVec3f = @Vector(3, f32);
pub const AVec2f = @Vector(2, f32);

pub fn len_3f(vec: AVec3f) f32 {
    const temp = vec * vec;
    return @sqrt(temp[0] + temp[1] + temp[2]);
}
pub fn len_2f(vec: AVec2f) f32 {
    const temp = vec * vec;
    return @sqrt(temp[0] + temp[1] + temp[2]);
}

pub fn lenSqrt_3f(vec: AVec3f) f32 {
    const temp = vec * vec;
    return temp[0] + temp[1] + temp[2];
}
pub fn lenSqrt_2f(vec: AVec2f) f32 {
    const temp = vec * vec;
    return temp[0] + temp[1] + temp[2];
}

pub fn normalize_3f(vec: AVec3f) Vec3f {
    if (lenSqrt_3f(vec) == 0)
        return vec;

    const length = len_3f(vec);

    return vec / @as(AVec3f, @splat(length));
}
pub fn normalize_2f(vec: AVec3f) Vec3f {
    if (lenSqrt_2f(vec) == 0)
        return vec;

    const length = len_2f(vec);

    return vec / @as(AVec2f, @splat(length));
}

pub fn dot_3f(a: Vec3f, b: Vec3f) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}
pub fn dot_2f(a: Vec2f, b: Vec2f) f32 {
    return a[0] * b[0] + a[1] * b[1];
}

pub fn rotToDir(rot: Vec3f) Vec3f {
    const x_cos = @cos(rot[0]);
    const x_sin = @sin(rot[0]);
    const y_sin = @sin(rot[1]);

    const perc = 1 - @abs(y_sin);
    return normalize_3f(.{ x_cos * perc, y_sin, x_sin * perc });
}

pub fn angle(a: AVec3f, b: AVec3f) f32 {
    const product = dot_3f(a, b);

    const a_len = len_3f(a);
    const b_len = len_3f(b);

    return std.math.acos(product / (a_len * b_len));
}

pub fn cross(a: Vec3f, b: Vec3f) Vec3f {
    return .{
        a[1] * b[2] - a[2] * b[1],
        -(a[0] * b[2] - a[2] * b[0]),
        a[0] * b[1] - a[1] * b[0],
    };
}
