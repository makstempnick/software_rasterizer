const std = @import("std");
const zm = @import("zm");

const Vec = zm.Vec;
const Mat = zm.Mat;
const Quat = zm.Quat;

const Self = @This();

pos: Vec,
rot: Quat,
scale: Vec,

mesh: usize,

pub fn init(pos: Vec, rot: Quat, scale: Vec, mesh: usize) Self {
    return .{
        .pos = pos,
        .rot = rot,
        .scale = scale,

        .mesh = mesh,
    };
}
