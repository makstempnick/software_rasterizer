const std = @import("std");
const zm = @import("zm");

const App = @import("App.zig");

const f32x4 = zm.f32x4;
const f32x4s = zm.f32x4s;

pub const quart_rot = half_rot / 2.0;
pub const half_rot = std.math.pi;
pub const full_rot = half_rot * 2.0;

pub const right = zm.f32x4(1, 0, 0, 0);
pub const up = zm.f32x4(0, 1, 0, 0);
pub const forward = zm.f32x4(0, 0, 1, 0);

pub fn remRot(rot: f32) f32 {
    if (rot < 0) {
        return full_rot - rot;
    }

    if (rot > full_rot) {
        return rot - full_rot;
    }

    return rot;
}
