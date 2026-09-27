const std = @import("std");
const zm = @import("zm");
const math = @import("math.zig");

const Input = @import("Input.zig");

const Vec = zm.Vec;
const Mat = zm.Mat;
const Quat = zm.Quat;
const Plane = math.Plane;

//

const Self = @This();

pos: Vec,
rot: Quat,
fov: f32,
near: f32,
far: f32,

move_speed: Vec,
rot_speed: Vec,

pub fn init(pos: Vec, rot: Quat, fov: f32, near: f32, far: f32, move_speed: Vec, rot_speed: Vec) Self {
    return .{
        .pos = pos,
        .rot = rot,
        .fov = fov,
        .near = near,
        .far = far,

        .move_speed = move_speed,
        .rot_speed = rot_speed,
    };
}
pub fn getRight(self: *Self) Vec {
    return zm.rotate(self.rot, math.right);
}
pub fn getUp(self: *Self) Vec {
    return zm.rotate(self.rot, math.up);
}
pub fn getForward(self: *Self) Vec {
    return zm.rotate(self.rot, math.forward);
}
pub fn getViewMat(self: *Self) Mat {
    return zm.lookToLh(self.pos, self.getForward(), math.up);
}
pub fn getClipMat(self: *Self, aspect: f32) Mat {
    return zm.perspectiveFovLh(self.fov, aspect, self.near, self.far);
}
pub fn getNearPlane(self: *Self) Plane {
    return .{ .{ 0, 0, self.near, 1 }, .{ 0, 0, 1, 0 } };
}
pub fn getFarPlane(self: *Self) Plane {
    return .{ .{ 0, 0, self.far, 1 }, .{ 0, 0, -1, 0 } };
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
    const up = math.up;
    const forward = self.getForward();

    self.pos += (right * x_multiplier + up * y_multiplier + forward * z_multiplier) * self.move_speed;
}
pub fn rotate(self: *Self, input: *Input, dt: f32) void {
    const dt_vec = zm.f32x4(dt, dt, dt, 1);

    const delta = zm.f32x4(input.mouse_delta[1], input.mouse_delta[0], 0, 0);

    var euler = blk: {
        const temp = zm.quatToRollPitchYaw(self.rot);
        break :blk zm.f32x4(temp[0], temp[1], temp[2], 0);
    };

    euler += delta * self.rot_speed * dt_vec;

    euler[0] = std.math.clamp(euler[0], -math.quart_rot + 0.2, math.quart_rot - 0.2);

    self.rot = zm.quatFromRollPitchYawV(euler);
}
pub fn localProjVec(self: *Self, aspect: f32, pos: Vec) Vec {
    const view_mat = self.getViewMat();
    const clip_mat = self.getClipMat(aspect);

    const pos_to_view = zm.mul(pos, view_mat);
    const pos_to_clip = zm.mul(pos_to_view, clip_mat);

    return pos_to_clip;
}
pub fn localProjMat(self: *Self, aspect: f32, obj_mat: Mat) Mat {
    const view_mat = self.getViewMat();
    const clip_mat = self.getClipMat(aspect);

    const mat_to_view = zm.mul(obj_mat, view_mat);
    const mat_to_clip = zm.mul(mat_to_view, clip_mat);

    return mat_to_clip;
}
