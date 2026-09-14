const std = @import("std");
const sdl = @import("sdl");
const utils = @import("utils");

const Allocator = std.mem.Allocator;
const Buffer = utils.Buffer;
const Window = sdl.video.Window;
const InitFlags = sdl.InitFlags;
const FramerateCapper = sdl.extras.FramerateCapper;
const Input = @import("input.zig").Input;

pub const App = struct {
    const Self = @This();

    running: bool = true,

    init_flags: InitFlags,
    window: Window,
    fps_cap: FramerateCapper(f32),
    dt: f32 = 0,
    thread_states: []bool,

    render_buffer: Buffer,
    display_buffer: Buffer,

    input: Input,

    pub fn init(allocator: Allocator) !Self {
        const init_flags = InitFlags{ .video = true };

        try sdl.init(init_flags);

        const window = try Window.init("3d_raycasting_engine", 600, 600, .{});
        const win_size = try window.getSize();
        const win_width = win_size[0];
        const win_height = win_size[1];

        const surface = try window.getSurface();
        const pixels = surface.getPixels().?;

        try sdl.mouse.setWindowRelativeMode(window, true);

        const fps_cap = FramerateCapper(f32){ .mode = .{ .limited = 60 } };

        const core_count = try std.Thread.getCpuCount();
        const thread_states = try allocator.alloc(bool, core_count);

        const render_buffer = try Buffer.init(allocator, 100, 100);
        render_buffer.fill(.{ 0, 0, 0, 255 });

        const display_buffer = Buffer.from(win_width, win_height, pixels);
        display_buffer.fill(.{ 0, 0, 0, 255 });

        const input = try Input.init(allocator);

        return .{
            .init_flags = init_flags,
            .window = window,
            .fps_cap = fps_cap,
            .thread_states = thread_states,

            .render_buffer = render_buffer,
            .display_buffer = display_buffer,

            .input = input,
        };
    }
    pub fn deinit(self: *Self, allocator: Allocator) void {
        sdl.mouse.setWindowRelativeMode(self.window, false) catch
            std.debug.print("cant disable relative mode !!!", .{});

        self.window.deinit();
        allocator.free(self.thread_states);

        self.render_buffer.deinit(allocator);

        self.input.deinit(allocator);

        sdl.quit(self.init_flags);
        sdl.shutdown();
    }
    pub fn start(self: *Self) !void {
        self.gameLoop();
    }
    fn gameLoop(self: *Self) void {
        while (self.running) {
            self.dt = self.fps_cap.delay();

            std.debug.print("FPS: {}\n", .{1 / self.dt});

            self.handleEvents() catch
                std.debug.print("cant handle events!!!!!!!\n", .{});

            if (self.input.keyDown(.escape))
                self.running = false;

            self.input.endStep();

            self.window.updateSurface() catch {};
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
};

pub fn main() !void {
    var allocator = std.heap.DebugAllocator(.{}).init;

    const gpa = allocator.allocator();

    var app = try App.init(gpa);

    defer {
        app.deinit(gpa);
        _ = allocator.deinit();
    }

    try app.start();
}
