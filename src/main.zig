const std = @import("std");
const sdl = @import("sdl");
const utils = @import("utils");

const Allocator = std.mem.Allocator;
const Buffer = utils.Buffer;
const Window = sdl.video.Window;
const InitFlags = sdl.InitFlags;
const FramerateCapper = sdl.extras.FramerateCapper;

pub const App = struct {
    const Self = @This();

    running: bool = true,

    init_flags: InitFlags,
    window: Window,
    fps_cap: FramerateCapper(f32),
    dt: f32 = 0,

    render_buffer: Buffer,
    display_buffer: Buffer,

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

        const render_buffer = try Buffer.init(allocator, 100, 100);
        render_buffer.fill(.{ 0, 0, 0, 255 });

        const display_buffer = Buffer.from(win_width, win_height, pixels);
        display_buffer.fill(.{ 0, 0, 0, 255 });

        return .{
            .init_flags = init_flags,
            .window = window,
            .fps_cap = fps_cap,

            .render_buffer = render_buffer,
            .display_buffer = display_buffer,
        };
    }
    pub fn deinit(self: *Self, allocator: Allocator) void {
        sdl.mouse.setWindowRelativeMode(self.window, false) catch
            std.debug.print("cant disable relative mode !!!", .{});

        self.window.deinit();
        self.render_buffer.deinit(allocator);

        sdl.quit(self.init_flags);
        sdl.shutdown();
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
}
