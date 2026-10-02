const std = @import("std");
const zm = @import("zm");
const math = @import("math.zig");

test "lerp" {
    _ = zm.lerpV(0.0, 1.0, 0.5);
}
