const std = @import("std");
const zm = @import("zm");
const math = @import("math.zig");

const App = @import("App.zig");
const Thread = std.Thread;
const Plane = math.Plane;
const Triangle = math.Triangle;
const Mesh = @import("Mesh.zig");

pub fn renderMesh(app: *App, mesh: *Mesh) void {
    const screen_edges = [4]Plane{
        .{ .{ 0, 0, 0, 1 }, .{ 1, 0, 0, 0 } },
        .{ .{ 1, 0, 0, 1 }, .{ -1, 0, 0, 0 } },
        .{ .{ 0, 0, 0, 1 }, .{ 0, 1, 0, 0 } },
        .{ .{ 0, 1, 0, 1 }, .{ 0, -1, 0, 0 } },
    };

    for (0..mesh.indices.len / 3) |i| {
        const ind0 = mesh.indices[3 * i];
        const ind1 = mesh.indices[3 * i + 1];
        const ind2 = mesh.indices[3 * i + 2];

        const v0 = mesh.vertices[ind0];
        const v1 = mesh.vertices[ind1];
        const v2 = mesh.vertices[ind2];

        const t0 = mesh.tex_coords[ind0];
        const t1 = mesh.tex_coords[ind1];
        const t2 = mesh.tex_coords[ind2];

        const triangle = Triangle{ v0, v1, v2 };
        const tex_coords = Triangle{ t0, t1, t2 };

        const pos_diff = app.camera.pos - math.getTriangleMiddle(triangle);

        const dot = zm.dot3(pos_diff, math.getTriangleNormal(triangle));

        if (dot[0] < 0)
            continue;

        const projected = math.localCamProjTriangle(triangle, app.render_aspect, &app.camera);

        const near_plane = app.camera.getNearPlane();
        const far_plane = app.camera.getFarPlane();

        var depth_clipped_0: [2]Triangle = undefined;
        const depth_amount_0 = math.clipTriangleAgainstPlane(projected, near_plane, &depth_clipped_0);

        for (0..depth_amount_0) |j| {
            var depth_clipped_1: [2]Triangle = undefined;
            const depth_amount_1 = math.clipTriangleAgainstPlane(depth_clipped_0[j], far_plane, &depth_clipped_1);

            for (0..depth_amount_1) |k| {
                var screen_clipped_0: [2]Triangle = undefined;

                const screen_amount_0 = math.clipTriangleAgainstPlane(math.screenProjTriangle(depth_clipped_1[k]), screen_edges[0], &screen_clipped_0);

                for (0..screen_amount_0) |l| {
                    var screen_clipped_1: [2]Triangle = undefined;

                    const screen_amount_1 = math.clipTriangleAgainstPlane(screen_clipped_0[l], screen_edges[1], &screen_clipped_1);

                    for (0..screen_amount_1) |m| {
                        var screen_clipped_2: [2]Triangle = undefined;

                        const screen_amount_2 = math.clipTriangleAgainstPlane(screen_clipped_1[m], screen_edges[2], &screen_clipped_2);

                        for (0..screen_amount_2) |n| {
                            var screen_clipped_3: [2]Triangle = undefined;

                            const screen_amount_3 = math.clipTriangleAgainstPlane(screen_clipped_2[n], screen_edges[3], &screen_clipped_3);

                            for (0..screen_amount_3) |o|
                                renderTriangle(app, screen_clipped_3[o], tex_coords, mesh.tex_id);

                            // this is ugly af
                            // i tried the stack approach but it didnt work
                            // so why not this :3
                        }
                    }
                }
            }
        }
    }
}
/// triangle must already be screen space !!!!!!!!!!
pub fn renderTriangle(app: *App, triangle: Triangle, tex_coords: Triangle, tex_id: usize) void {
    const texture = app.textures.items[tex_id];
    _ = texture;

    // TODO: rasterization

    var x0: i32 = @trunc((@as(f32, @floatFromInt(app.render_buffer.width - 1)) * triangle[0][0]));
    // var y0: i32 = @trunc((@as(f32, @floatFromInt(app.render_buffer.height - 1)) * triangle[0][1]));
    var y0: i32 = @trunc(@as(f32, @floatFromInt(app.render_buffer.height - 1)) - (@as(f32, @floatFromInt(app.render_buffer.height - 1)) * triangle[0][1]));

    var x1: i32 = @trunc((@as(f32, @floatFromInt(app.render_buffer.width - 1)) * triangle[1][0]));
    // var y1: i32 = @trunc((@as(f32, @floatFromInt(app.render_buffer.height - 1)) * triangle[1][1]));
    var y1: i32 = @trunc(@as(f32, @floatFromInt(app.render_buffer.height - 1)) - (@as(f32, @floatFromInt(app.render_buffer.height - 1)) * triangle[1][1]));

    var x2: i32 = @trunc((@as(f32, @floatFromInt(app.render_buffer.width - 1)) * triangle[2][0]));
    // var y2: i32 = @trunc((@as(f32, @floatFromInt(app.render_buffer.height - 1)) * triangle[2][1]));
    var y2: i32 = @trunc(@as(f32, @floatFromInt(app.render_buffer.height - 1)) - (@as(f32, @floatFromInt(app.render_buffer.height - 1)) * triangle[2][1]));

    if (x0 < 0 or y0 < 0 or x1 < 0 or y1 < 0 or x2 < 0 or y2 < 0)
        std.debug.print("!!!!!!!!!!!!!!\n", .{});

    var _u0 = tex_coords[0][0];
    var _v0 = tex_coords[0][1];

    var _u1 = tex_coords[1][0];
    var _v1 = tex_coords[1][1];

    var _u2 = tex_coords[2][0];
    var _v2 = tex_coords[2][1];

    if (y1 < y0) {
        std.mem.swap(i32, &y0, &y1);
        std.mem.swap(i32, &x0, &x1);

        std.mem.swap(f32, &_u0, &_u1);
        std.mem.swap(f32, &_v0, &_v1);
    }

    if (y2 < y0) {
        std.mem.swap(i32, &y0, &y2);
        std.mem.swap(i32, &x0, &x2);

        std.mem.swap(f32, &_u0, &_u2);
        std.mem.swap(f32, &_v0, &_v2);
    }

    if (y2 < y1) {
        std.mem.swap(i32, &y1, &y2);
        std.mem.swap(i32, &x1, &x2);

        std.mem.swap(f32, &_u1, &_u2);
        std.mem.swap(f32, &_v1, &_v2);
    }

    // intcasts when i was testing it with usize
    drawLine(app, @intCast(x0), @intCast(y0), @intCast(x1), @intCast(y1));
    drawLine(app, @intCast(x1), @intCast(y1), @intCast(x2), @intCast(y2));
    drawLine(app, @intCast(x2), @intCast(y2), @intCast(x0), @intCast(y0));
}
pub fn drawLine(app: *App, x0: i32, y0: i32, x1: i32, y1: i32) void {
    if (@abs(x1 - x0) > @abs(y1 - y0)) {
        if (x1 > x0) {
            drawLineH(app, x0, y0, x1, y1);
        } else {
            drawLineH(app, x1, y1, x0, y0);
        }
    } else {
        if (y1 > y0) {
            drawLineV(app, x0, y0, x1, y1);
        } else {
            drawLineV(app, x1, y1, x0, y0);
        }
    }
}
fn drawLineH(app: *App, x0: i32, y0: i32, x1: i32, y1: i32) void {
    const dx = x1 - x0;
    var dy = y1 - y0;

    var dir: i32 = 1;

    if (dy < 0) {
        dir = -1;
        dy = -dy;
    }

    var p = 2 * dy - dx;
    var y = y0;

    for (0..@intCast(@abs(dx) + 1)) |x| {
        const final_x = x0 + @as(i32, @intCast(x));

        if (final_x > 0 and final_x < app.render_buffer.width and y > 0 and y < app.render_buffer.height)
            app.render_buffer.setColor(@intCast(final_x), @intCast(y), .{ 255, 255, 255, 255 });

        if (p >= 0) {
            y += dir;
            p += 2 * (dy - dx);
        } else {
            p += 2 * dy;
        }
    }
}
fn drawLineV(app: *App, x0: i32, y0: i32, x1: i32, y1: i32) void {
    const dy = y1 - y0;
    var dx = x1 - x0;

    var dir: i32 = 1;

    if (dx < 0) {
        dir = -1;
        dx = -dx;
    }

    var p = 2 * dx - dy;
    var x = x0;

    for (0..@intCast(@abs(dy) + 1)) |y| {
        const final_y = y0 + @as(i32, @intCast(y));

        if (x > 0 and x < app.render_buffer.width and final_y > 0 and final_y < app.render_buffer.height)
            app.render_buffer.setColor(@intCast(x), @intCast(final_y), .{ 255, 255, 255, 255 });

        if (p >= 0) {
            x += dir;
            p += 2 * (dx - dy);
        } else {
            p += 2 * dx;
        }
    }
}

pub fn display(app: *App) !void {
    @memset(app.thread_states[0..], false);

    const core_count = app.thread_states.len;

    const display_height = app.display_buffer.height;

    const display_stride = display_height / core_count;

    for (0..core_count) |i| {
        const display_y0 = display_stride * i;
        const display_y1 = blk: {
            if (i < core_count - 1) {
                break :blk display_stride * (i + 1);
            } else {
                break :blk display_height;
            }
        };

        const thread = try Thread.spawn(.{}, displayThread, .{ app, display_y0, display_y1, i });
        thread.detach();
    }

    while (true) {
        var done: u8 = 0;

        for (app.thread_states) |value| {
            if (value)
                done += 1;
        }

        if (done == core_count)
            break;
    }

    try app.window.updateSurface();
}
fn displayThread(app: *App, y0: usize, y1: usize, index: usize) void {
    const width = app.display_buffer.width;
    const height = app.display_buffer.height;

    for (y0..y1) |screen_y| {
        for (0..width) |screen_x| {
            const perc_x = @as(f32, @floatFromInt(screen_x)) / @as(f32, @floatFromInt(width));
            const perc_y = @as(f32, @floatFromInt(screen_y)) / @as(f32, @floatFromInt(height));

            const color = app.render_buffer.sample(perc_x, perc_y).?;
            const corrected_color = [_]u8{ color[2], color[1], color[0], color[3] };

            app.display_buffer.setColor(screen_x, screen_y, corrected_color);

            if (!app.running)
                return;
        }
    }

    app.thread_states[index] = true;
}
