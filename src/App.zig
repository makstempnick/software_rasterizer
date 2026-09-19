const std = @import("std");
const sdl = @import("sdl");
const utils = @import("utils");
const zm = @import("zm");
const math = @import("math.zig");
const rendering = @import("rendering.zig");

const Allocator = std.mem.Allocator;
const Buffer = utils.Buffer;
const Window = sdl.video.Window;
const InitFlags = sdl.InitFlags;
const FramerateCapper = sdl.extras.FramerateCapper;
const Input = @import("Input.zig");
const Camera = @import("Camera.zig");

const Triangle = @import("Triangle.zig");
const Mesh = @import("Mesh.zig");
const Model = @import("Model.zig");

const f32x4 = zm.f32x4;
const f32x4s = zm.f32x4s;

//

const Self = @This();

running: bool = true,

init_flags: InitFlags,
window: Window,
fps_cap: FramerateCapper(f32),
dt: f32 = 0,
thread_states: []bool,

render_buffer: Buffer,
display_buffer: Buffer,

render_aspect: f32,
display_aspect: f32,

input: Input,

camera: Camera,

meshes: std.ArrayList(Mesh),
models: std.ArrayList(Model),

pub fn init(gpa: Allocator) !Self {
    const init_flags = InitFlags{ .video = true };

    try sdl.init(init_flags);

    const window = try Window.init("software_rasterizer", 600, 600, .{});
    const win_size = try window.getSize();
    const win_width = win_size[0];
    const win_height = win_size[1];

    const surface = try window.getSurface();
    const pixels = surface.getPixels().?;

    try sdl.mouse.setWindowRelativeMode(window, true);

    const fps_cap = FramerateCapper(f32){ .mode = .{ .limited = 180 } };

    const core_count = try std.Thread.getCpuCount();
    const thread_states = try gpa.alloc(bool, core_count);

    const render_buffer = try Buffer.init(gpa, 100, 100);
    render_buffer.fill(.{ 0, 0, 0, 255 });

    const display_buffer = Buffer.from(win_width, win_height, pixels);
    display_buffer.fill(.{ 0, 0, 0, 255 });

    const render_aspect = @as(f32, @floatFromInt(render_buffer.height)) / @as(f32, @floatFromInt(render_buffer.width));
    const display_aspect = @as(f32, @floatFromInt(display_buffer.height)) / @as(f32, @floatFromInt(display_buffer.width));

    const input = try Input.init(gpa);

    const cam_pos = f32x4(0, 0, 0, 1);
    const cam_rot = zm.quatFromMat(zm.lookToLh(cam_pos, math.forward, math.up));
    const camera = Camera.init(cam_pos, cam_rot, math.quart_rot, f32x4s(6), f32x4s(1));

    const meshes = std.ArrayList(Mesh).empty;
    const models = std.ArrayList(Model).empty;

    return .{
        .init_flags = init_flags,
        .window = window,
        .fps_cap = fps_cap,
        .thread_states = thread_states,

        .render_buffer = render_buffer,
        .display_buffer = display_buffer,

        .render_aspect = render_aspect,
        .display_aspect = display_aspect,

        .input = input,

        .camera = camera,

        .meshes = meshes,
        .models = models,
    };
}
pub fn deinit(self: *Self, gpa: Allocator) void {
    sdl.mouse.setWindowRelativeMode(self.window, false) catch
        std.debug.print("cant disable relative mode !!!", .{});

    self.window.deinit();
    gpa.free(self.thread_states);

    self.render_buffer.deinit(gpa);

    self.input.deinit(gpa);

    for (self.meshes.items) |*mesh|
        mesh.deinit(gpa);

    self.meshes.deinit(gpa);
    self.models.deinit(gpa);

    sdl.quit(self.init_flags);
    sdl.shutdown();
}
pub fn start(self: *Self, gpa: Allocator) !void {
    std.debug.print("right: {}\n", .{self.camera.getRight()});
    std.debug.print("up: {}\n", .{self.camera.getUp()});
    std.debug.print("forward: {}\n", .{self.camera.getForward()});

    std.debug.print("view: {any}\n", .{self.camera.getViewMat()});

    try self.createMeshes(gpa);
    self.gameLoop();
}
fn createMeshes(self: *Self, gpa: Allocator) !void {
    const triangles = try gpa.alloc(Triangle, 12);

    triangles[0] = Triangle.init(.{
        f32x4(0, 0, 10, 1),
        f32x4(0, 4, 10, 1),
        f32x4(4, 0, 10, 1),
    });
    triangles[1] = Triangle.init(.{
        f32x4(0, 4, 10, 1),
        f32x4(4, 4, 10, 1),
        f32x4(4, 0, 10, 1),
    });

    triangles[2] = Triangle.init(.{
        f32x4(0, 0, 14, 1),
        f32x4(0, 4, 14, 1),
        f32x4(4, 0, 14, 1),
    }).getFlipped();
    triangles[3] = Triangle.init(.{
        f32x4(0, 4, 14, 1),
        f32x4(4, 4, 14, 1),
        f32x4(4, 0, 14, 1),
    }).getFlipped();

    triangles[4] = Triangle.init(.{
        f32x4(0, 0, 10, 1),
        f32x4(0, 0, 14, 1),
        f32x4(0, 4, 14, 1),
    });
    triangles[5] = Triangle.init(.{
        f32x4(0, 4, 14, 1),
        f32x4(0, 4, 10, 1),
        f32x4(0, 0, 10, 1),
    });

    triangles[6] = Triangle.init(.{
        f32x4(4, 0, 10, 1),
        f32x4(4, 0, 14, 1),
        f32x4(4, 4, 14, 1),
    }).getFlipped();
    triangles[7] = Triangle.init(.{
        f32x4(4, 4, 14, 1),
        f32x4(4, 4, 10, 1),
        f32x4(4, 0, 10, 1),
    }).getFlipped();

    triangles[8] = Triangle.init(.{
        f32x4(0, 0, 14, 1),
        f32x4(0, 0, 10, 1),
        f32x4(4, 0, 10, 1),
    });
    triangles[9] = Triangle.init(.{
        f32x4(0, 0, 14, 1),
        f32x4(4, 0, 10, 1),
        f32x4(4, 0, 14, 1),
    });

    triangles[10] = Triangle.init(.{
        f32x4(0, 4, 14, 1),
        f32x4(0, 4, 10, 1),
        f32x4(4, 4, 10, 1),
    }).getFlipped();
    triangles[11] = Triangle.init(.{
        f32x4(0, 4, 14, 1),
        f32x4(4, 4, 10, 1),
        f32x4(4, 4, 14, 1),
    }).getFlipped();

    const mesh = Mesh.init(triangles);
    try self.meshes.append(gpa, mesh);
}
fn gameLoop(self: *Self) void {
    while (self.running) {
        self.dt = self.fps_cap.delay();

        std.debug.print("FPS: {}\n", .{1 / self.dt});

        self.handleEvents() catch
            std.debug.print("cant handle events!!!!!!!\n", .{});

        self.camera.move(&self.input, self.dt);
        self.camera.rotate(&self.input, self.dt);

        self.render_buffer.fill(.{ 0, 0, 0, 255 });

        for (self.meshes.items) |*mesh|
            for (mesh.triangles) |*triangle|
                rendering.renderTriangle(self, triangle);

        rendering.display(self) catch
            std.debug.print("cant display!!!!!!!!!", .{});

        if (self.input.keyDown(.escape))
            self.running = false;

        self.input.endStep();
    }
}
fn handleEvents(self: *Self) !void {
    while (sdl.events.poll()) |event| {
        switch (event) {
            .quit => self.running = false,
            .terminating => self.running = false,
            else => {},
        }

        self.input.step(event);
    }
}
