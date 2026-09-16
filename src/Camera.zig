const std = @import("std");
const zm = @import("zm");
const math = @import("math.zig");

const Input = @import("Input.zig");

//

const Self = @This();

pos: zm.Vec,
rot: zm.Quat,
fov: f32,

move_speed: zm.Vec,
rot_speed: zm.Vec,

pub fn init(pos: zm.Vec, rot: zm.Vec, fov: f32, move_speed: zm.Vec, rot_speed: zm.Vec) Self {
    return .{
        .pos = pos,
        .rot = rot,
        .fov = fov,

        .move_speed = move_speed,
        .rot_speed = rot_speed,
    };
}
pub fn getRight(self: *Self) zm.Vec {
    return zm.rotate(self.rot, zm.f32x4(1, 0, 0, 0));
}
pub fn getUp(self: *Self) zm.Vec {
    return zm.rotate(self.rot, zm.f32x4(0, 1, 0, 0));
}
pub fn getForward(self: *Self) zm.Vec {
    return zm.rotate(self.rot, zm.f32x4(0, 0, 1, 0));
}
pub fn getProjMat(self: *Self, aspect: f32) zm.Mat {
    return zm.perspectiveFovLh(self.fov, aspect, 0.01, 100);
}
pub fn getViewMat(self: *Self) zm.Mat {
    return zm.lookToLh(self.pos, self.getForward(), zm.f32x4(0, 1, 0, 0));
}
pub fn move(self: *Self, input: *Input, dt: f32) void {
    const dt_vec = zm.f32x4s(dt);

    var x_multiplier = zm.f32x4s(0);

    if (input.keyDown(.a))
        x_multiplier -= dt_vec;
    if (input.keyDown(.d))
        x_multiplier += dt_vec;

    var y_multiplier = zm.f32x4s(0);
    if (input.keyDown(.left_shift))
        y_multiplier -= dt_vec;
    if (input.keyDown(.space))
        y_multiplier += dt_vec;

    var z_multiplier = zm.f32x4s(0);
    if (input.keyDown(.s))
        z_multiplier -= dt_vec;
    if (input.keyDown(.w))
        z_multiplier += dt_vec;

    const right = self.getRight();
    const up = self.getUp();
    const forward = self.getForward();

    self.pos += (right * x_multiplier + up * y_multiplier + forward * z_multiplier) * self.move_speed;
}
pub fn rotate(self: *Self, input: *Input, dt: f32) void {
    const dt_vec = zm.f32x4s(dt);

    const delta = zm.f32x4(input.mouse_delta[1], input.mouse_delta[0], 0, 0);

    var euler = blk: {
        const temp = zm.quatToRollPitchYaw(self.rot);
        break :blk zm.f32x4(temp[0], temp[1], temp[2], 0);
    };

    euler += delta * self.rot_speed * dt_vec;

    euler[0] = std.math.clamp(euler[0], -math.half_rot, math.half_rot);
    // euler[1] = math.remRot(euler[1]);

    self.rot = zm.quatFromRollPitchYawV(euler);
}
