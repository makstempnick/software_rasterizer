const std = @import("std");

pub const quart_rot = half_rot / 2.0;
pub const half_rot = std.math.pi;
pub const full_rot = half_rot * 2.0;

pub fn remRot(rot: f32) f32 {
    if (rot < 0) {
        return full_rot - rot;
    }

    if (rot > full_rot) {
        return rot - full_rot;
    }

    return rot;
}
