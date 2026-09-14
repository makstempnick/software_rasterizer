const std = @import("std");
const sdl = @import("sdl");

const Allocator = std.mem.Allocator;
const Key = sdl.Scancode;

// smh took it from the 3d raycaster
pub const Input = struct {
    const Self = @This();

    old_keyboard_keys: []bool,
    new_keyboard_keys: []bool,

    old_mouse_pos: [2]f32 = .{ 0, 0 },
    new_mouse_pos: [2]f32 = .{ 0, 0 },
    mouse_delta: [2]f32 = .{ 0, 0 },

    pub fn init(allocator: Allocator) !Self {
        const len = @typeInfo(Key).@"enum".fields.len;

        const old_keyboard_keys = try allocator.alloc(bool, len);
        const new_keyboard_keys = try allocator.alloc(bool, len);

        @memset(new_keyboard_keys[0..], false);
        @memset(old_keyboard_keys[0..], false);

        return .{
            .old_keyboard_keys = old_keyboard_keys,
            .new_keyboard_keys = new_keyboard_keys,
        };
    }
    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.old_keyboard_keys);
        allocator.free(self.new_keyboard_keys);
    }
    pub fn step(self: *Self, event: sdl.events.Event) void {
        switch (event) {
            .key_down => |key| {
                const index = @intFromEnum(key.scancode.?);
                self.new_keyboard_keys[index] = true;
            },
            .key_up => |key| {
                const index = @intFromEnum(key.scancode.?);
                self.new_keyboard_keys[index] = false;
            },
            .mouse_motion => |motion| {
                self.new_mouse_pos[0] = motion.x;
                self.new_mouse_pos[1] = motion.y;

                self.mouse_delta[0] = motion.x_rel;
                self.mouse_delta[1] = motion.y_rel;
            },
            else => {},
        }
    }
    pub fn endStep(self: *Self) void {
        @memcpy(self.old_keyboard_keys[0..], self.new_keyboard_keys[0..]);
        self.old_mouse_pos = self.new_mouse_pos;
        @memset(self.mouse_delta[0..], 0);
    }
    pub fn keyDown(self: *Self, key: Key) bool {
        const index = @intFromEnum(key);
        return self.new_keyboard_keys[index];
    }
    pub fn keyUp(self: *Self, key: Key) bool {
        const index = @intFromEnum(key);
        return !self.new_keyboard_keys[index];
    }
    pub fn keyPressed(self: *Self, key: Key) bool {
        const index = @intFromEnum(key);
        return self.new_keyboard_keys[index] and !self.old_keyboard_keys[index];
    }
    pub fn keyReleased(self: *Self, key: Key) bool {
        const index = @intFromEnum(key);
        return !self.new_keyboard_keys[index] and self.old_keyboard_keys[index];
    }
};
