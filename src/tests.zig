const std = @import("std");
const zm = @import("zm");
const math = @import("math.zig");

test "quat" {
    const euler = zm.f32x4(math.half_rot, 0, 0, 0);
    const quat = zm.quatFromRollPitchYawV(euler);
    std.debug.print("euler: {};\n quat: {};\n", .{ euler, quat });
}
