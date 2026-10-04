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

const Vec = zm.Vec;
const Triangle = math.Triangle;
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
depth_buffer: []f32,

render_aspect: f32,
display_aspect: f32,

input: Input,

camera: Camera,

meshes: std.ArrayList(Mesh),
models: std.ArrayList(Model),
textures: std.ArrayList(Buffer),

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

    const render_buffer = try Buffer.init(gpa, 400, 400);
    render_buffer.fill(.{ 0, 0, 0, 255 });

    const display_buffer = Buffer.from(win_width, win_height, pixels);
    display_buffer.fill(.{ 0, 0, 0, 255 });

    const depth_buffer = try gpa.alloc(f32, render_buffer.width * render_buffer.height);

    const render_aspect = @as(f32, @floatFromInt(render_buffer.height)) / @as(f32, @floatFromInt(render_buffer.width));
    const display_aspect = @as(f32, @floatFromInt(display_buffer.height)) / @as(f32, @floatFromInt(display_buffer.width));

    const input = try Input.init(gpa);

    const cam_pos = f32x4(0, 0, -5, 1);
    const cam_rot = zm.quatFromMat(zm.lookToLh(cam_pos, math.forward, math.up));
    const camera = Camera.init(cam_pos, cam_rot, math.quart_rot, 0.1, 100.0, f32x4s(6), f32x4s(1));

    const meshes = std.ArrayList(Mesh).empty;
    const models = std.ArrayList(Model).empty;
    const textures = std.ArrayList(Buffer).empty;

    return .{
        .init_flags = init_flags,
        .window = window,
        .fps_cap = fps_cap,
        .thread_states = thread_states,

        .render_buffer = render_buffer,
        .display_buffer = display_buffer,
        .depth_buffer = depth_buffer,

        .render_aspect = render_aspect,
        .display_aspect = display_aspect,

        .input = input,

        .camera = camera,

        .meshes = meshes,
        .models = models,
        .textures = textures,
    };
}
pub fn deinit(self: *Self, gpa: Allocator) void {
    sdl.mouse.setWindowRelativeMode(self.window, false) catch
        std.debug.print("cant disable relative mode !!!", .{});

    self.window.deinit();
    gpa.free(self.thread_states);

    self.render_buffer.deinit(gpa);
    gpa.free(self.depth_buffer);

    self.input.deinit(gpa);

    for (self.meshes.items) |*mesh|
        mesh.deinit(gpa);

    for (self.textures.items) |*texture|
        texture.deinit(gpa);

    self.meshes.deinit(gpa);
    self.models.deinit(gpa);
    self.textures.deinit(gpa);

    sdl.quit(self.init_flags);
    sdl.shutdown();
}
pub fn start(self: *Self, std_init: std.process.Init, gpa: Allocator) !void {
    try self.loadMeshes(std_init, gpa);
    try self.loadTextures(gpa);
    self.gameLoop();

    // _ = self;
    // _ = std_init;
    // _ = gpa;
}
fn loadMeshes(self: *Self, std_init: std.process.Init, gpa: Allocator) !void {
    // const cube = try Mesh.fromObjFile(gpa, std_init, "assets/Cube.obj");
    const teapot = try Mesh.fromObjFile(gpa, std_init, "assets/utah_teapot.obj");
    // try self.meshes.append(gpa, cube);
    try self.meshes.append(gpa, teapot);

    //     _ = std_init;

    //     const vertices = try gpa.alloc(Vec, 4);
    //     const tex_coords = try gpa.alloc(Vec, 4);
    //     const indices = try gpa.alloc(usize, 6);

    //     vertices[0] = zm.f32x4(-2, -2, 3, 1);
    //     vertices[1] = zm.f32x4(-2, 2, 3, 1);
    //     vertices[2] = zm.f32x4(2, 2, 3, 1);
    //     vertices[3] = zm.f32x4(2, -2, 3, 1);

    //     tex_coords[0] = zm.f32x4(0, 1, 0, 1);
    //     tex_coords[1] = zm.f32x4(0, 0, 0, 1);
    //     tex_coords[2] = zm.f32x4(1, 0, 0, 1);
    //     tex_coords[3] = zm.f32x4(1, 1, 0, 1);

    //     indices[0] = 0;
    //     indices[1] = 1;
    //     indices[2] = 2;

    //     indices[3] = 2;
    //     indices[4] = 3;
    //     indices[5] = 0;

    //     const mesh_2 = Mesh.init(vertices, tex_coords, indices);
    //     try self.meshes.append(gpa, mesh_2);
}
fn loadTextures(self: *Self, gpa: Allocator) !void {
    const wood = try loadTexture("assets/Rock060_1K-JPG_Color.png", gpa);
    try self.textures.append(gpa, wood);
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
        @memset(self.depth_buffer[0..], 0);

        for (self.meshes.items) |*mesh|
            rendering.renderMesh(self, mesh, 0);

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
pub fn loadTexture(path: [:0]const u8, gpa: Allocator) !Buffer {
    const file = blk: {
        const temp = try sdl.image.loadFile(path);
        defer temp.deinit();
        break :blk try temp.convertFormat(.packed_abgr_8_8_8_8);
    };

    const width = file.getWidth();
    const height = file.getHeight();

    const pixels = file.getPixels().?;
    const buffer = try Buffer.init(gpa, width, height);

    @memcpy(buffer.colors[0..], pixels[0..]);

    file.deinit();

    return buffer;
}
