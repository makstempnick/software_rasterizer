const std = @import("std");
const sdl = @import("sdl");
const utils = @import("utils");
const zm = @import("zm");
const root = @import("renderer");
const math = root.math;

const Allocator = std.mem.Allocator;

const Vec = zm.Vec;
const Mat = zm.Mat;
const Quat = zm.Quat;
const Plane = math.Plane;

pub fn main(init: std.process.Init) !void {
    const assets_path = init.minimal.args.vector[1];

    var allocator = std.heap.SafeAllocator.init(std.heap.page_allocator, .{});
    const gpa = allocator.allocator();

    defer sdl.shutdown();

    const flags = sdl.InitFlags{ .video = true };
    try sdl.init(flags);
    defer sdl.quit(flags);

    const window = try sdl.video.Window.init("teapot example", 400, 400, .{ .resizable = true });
    defer window.deinit();

    var fps = sdl.extras.FramerateCapper(f32){ .mode = .{ .limited = 60 } };

    const win_size = try window.getSize();
    const win_width = win_size[0];
    const win_height = win_size[1];

    const surface = try window.getSurface();
    const pixels = surface.getPixels().?;

    var render = utils.Buffer(u8, 4).from(win_width, win_height, pixels);
    var depth = try utils.Buffer(f32, 1).init(gpa, win_width, win_height);
    defer depth.deinit(gpa);

    var temp1: [1024]u8 = undefined;
    const obj_path = try std.mem.print(&temp1, "{s}/teapot.obj", .{assets_path});
    const obj = try loadObj(gpa, init.io, obj_path);

    var temp2: [1024]u8 = undefined;
    const texture_path = try std.mem.printSentinel(&temp2, "{s}/stone.png", .{assets_path}, 0);
    const texture = try loadTexture(gpa, texture_path);

    const vertices = obj[0];
    const tex_coords = obj[1];
    const indices = obj[2];

    defer {
        gpa.free(vertices);
        gpa.free(tex_coords);
        gpa.free(indices);

        texture.deinit(gpa);
    }

    const sampler = root.Sampler{
        .wrap_mode_u = .Repeat,
        .wrap_mode_v = .Repeat,
        .filter_mode = .Linear,
    };

    var renderer = root.Renderer{
        .surface = &render,
        .depth_buf = &depth,

        .eye_pos = zm.f32x4(0, 0, -7.5, 1),
        .aspect = @as(f32, @floatFromInt(render.width)) / @as(f32, @floatFromInt(render.height)),

        .vertices = vertices,
        .tex_coords = tex_coords,
        .indices = indices,
        .model_mat = zm.translation(0, -2, 0),

        .texture = &texture,
        .sampler = sampler,

        .cull_mode = .Back,
    };

    const keys: []bool = try gpa.alloc(bool, @typeInfo(sdl.Scancode).@"enum".field_names.len);
    defer gpa.free(keys);

    const speed = 5;

    var running = true;
    while (running) {
        const dt = fps.delay();
        // std.debug.print("dt: {}\n", .{@trunc(1 / dt)});

        render.clear(.{ 0, 0, 0, 255 });
        depth.clear(std.math.inf(f32));

        if (keys[@backingInt(sdl.Scancode.w)])
            renderer.eye_pos[2] += speed * dt;

        if (keys[@backingInt(sdl.Scancode.s)])
            renderer.eye_pos[2] -= speed * dt;

        try renderer.draw();

        try window.updateSurface();

        while (sdl.events.poll()) |event| {
            switch (event) {
                .quit => running = false,
                .terminating => running = false,
                .window_resized => |size| {
                    const new_surface = try window.getSurface();
                    const new_pixels = new_surface.getPixels().?;
                    render = .from(@intCast(size.width), @intCast(size.height), new_pixels);
                    depth.deinit(gpa);
                    depth = try .init(gpa, @intCast(size.width), @intCast(size.height));

                    renderer.aspect = @as(f32, @floatFromInt(render.width)) / @as(f32, @floatFromInt(render.height));
                },
                .key_down => |key| {
                    if (key.scancode) |scancode|
                        keys[@backingInt(scancode)] = true;
                },
                .key_up => |key| {
                    if (key.scancode) |scancode|
                        keys[@backingInt(scancode)] = false;
                },
                else => {},
            }
        }
    }
}

fn loadObj(gpa: Allocator, io: std.Io, path: []const u8) !struct { []Vec, []Vec, []usize } {
    var vertices = try std.ArrayList(Vec).initCapacity(gpa, 128);
    var tex_coords = try std.ArrayList(Vec).initCapacity(gpa, 128);
    var indices = try std.ArrayList(usize).initCapacity(gpa, 256);

    const dir = std.Io.Dir.cwd();
    const file = try dir.openFile(io, path, .{ .mode = .read_only });
    defer file.close(io);

    var read_buffer: [1024]u8 = undefined;
    @memset(read_buffer[0..], 0);
    var r_fs = file.reader(io, &read_buffer);
    var reader = &r_fs.interface;

    // VERTICES
    while (true) {
        const line = try reader.peekDelimiterExclusive('\n');

        if (line.len < 2) {
            _ = try reader.takeDelimiter('\n');
            continue;
        }

        if (std.mem.eql(u8, line[0..2], "v "))
            break;

        _ = try reader.takeDelimiter('\n');
    }

    while (true) {
        const line = try reader.peekDelimiterExclusive('\n');

        if (line.len < 2 or !std.mem.eql(u8, line[0..2], "v "))
            break;

        _ = try reader.takeDelimiter(' ');

        if (try reader.takeDelimiter('\n')) |positions| {
            var split_iter = std.mem.splitScalar(u8, positions, ' ');

            var vert = [4]f32{ 0, 0, 0, 1 };

            for (0..3) |i| {
                const pos = split_iter.next().?;
                const value = try std.fmt.parseFloat(f32, pos);
                vert[i] = value;
            }

            try vertices.append(gpa, vert);
        }
    }

    // TEX COORDS
    while (true) {
        const line = try reader.peekDelimiterExclusive('\n');

        if (line.len < 2) {
            _ = try reader.takeDelimiter('\n');
            continue;
        }

        if (std.mem.eql(u8, line[0..2], "vt"))
            break;

        _ = try reader.takeDelimiter('\n');
    }

    while (true) {
        const line = try reader.peekDelimiterExclusive('\n');

        if (line.len < 2 or !std.mem.eql(u8, line[0..2], "vt"))
            break;

        _ = try reader.takeDelimiter(' ');

        if (try reader.takeDelimiter('\n')) |positions| {
            var split_iter = std.mem.splitScalar(u8, positions, ' ');

            var coord = [4]f32{ 0, 0, 0, 1 };

            for (0..2) |i| {
                const pos = split_iter.next().?;
                const value = try std.fmt.parseFloat(f32, pos);
                coord[i] = value;
            }

            try tex_coords.append(gpa, coord);
        }
    }

    // INDICES
    while (true) {
        const line = try reader.peekDelimiterExclusive('\n');

        if (line.len < 2) {
            _ = try reader.takeDelimiter('\n');
            continue;
        }

        if (std.mem.eql(u8, line[0..2], "f "))
            break;

        _ = try reader.takeDelimiter('\n');
    }

    while (true) {
        const line = try reader.peekDelimiterExclusive('\n');

        if (line.len < 2 or !std.mem.eql(u8, line[0..2], "f "))
            break;

        for (0..3) |_| {
            _ = try reader.takeDelimiter(' ');

            if (try reader.takeDelimiter('/')) |data| {
                const index = try std.fmt.parseInt(usize, data, 10) - 1;
                try indices.append(gpa, index);
            }
        }

        _ = try reader.takeDelimiter('\n');

        if (reader.seek == reader.end)
            break;
    }

    var array_vertices = try gpa.alloc(Vec, vertices.items.len);
    var array_tex_coords = try gpa.alloc(Vec, tex_coords.items.len);
    var array_indices = try gpa.alloc(usize, indices.items.len);

    @memcpy(array_vertices[0..], vertices.items[0..]);
    @memcpy(array_tex_coords[0..], tex_coords.items[0..]);
    @memcpy(array_indices[0..], indices.items[0..]);

    vertices.deinit(gpa);
    tex_coords.deinit(gpa);
    indices.deinit(gpa);

    return .{
        array_vertices,
        array_tex_coords,
        array_indices,
    };
}
pub fn loadTexture(gpa: Allocator, path: [:0]const u8) !utils.Buffer(u8, 4) {
    const file = blk: {
        const temp = try sdl.image.loadFile(path);
        defer temp.deinit();
        break :blk try temp.convertFormat(.packed_abgr_8_8_8_8);
    };

    const width = file.getWidth();
    const height = file.getHeight();

    const pixels = file.getPixels().?;
    const buffer = try utils.Buffer(u8, 4).init(gpa, width, height);

    @memcpy(buffer.values[0..], pixels[0..]);

    file.deinit();

    return buffer;
}
