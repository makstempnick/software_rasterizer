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

        const triangle = Triangle{ v0, v1, v2 };

        const pos_diff = app.camera.pos - math.getTriangleMiddle(triangle);

        const dot = zm.dot3(pos_diff, math.getTriangleNormal(triangle));

        if (dot[0] < 0)
            continue;

        const projected = math.localCamProjTriangle(triangle, app.render_aspect, &app.camera);

        const near_plane = app.camera.getNearPlane();

        var depth_clipped: [2]Triangle = undefined;
        const depth_amount = math.clipTriangleAgainstPlane(projected, near_plane, &depth_clipped);

        for (0..depth_amount) |j| {
            app.triangle_stack.clearRetainingCapacity();

            app.triangle_stack.appendAssumeCapacity(math.screenProjTriangle(depth_clipped[j]));

            var screen_clipped: [2]Triangle = undefined;

            var new_triangles: usize = 1;

            for (screen_edges) |screen_edge| {
                var tris_to_add: usize = 0;

                while (new_triangles > 0) {
                    const popped = app.triangle_stack.pop().?;

                    new_triangles -= 1;

                    tris_to_add = math.clipTriangleAgainstPlane(popped, screen_edge, &screen_clipped);

                    for (0..tris_to_add) |k|
                        app.triangle_stack.appendAssumeCapacity(screen_clipped[k]);
                }

                new_triangles = app.triangle_stack.items.len;
            }

            for (app.triangle_stack.items) |final|
                renderTriangle(app, final);
        }
    }
}
/// triangle must already be screen space !!!!!!!!!!
pub fn renderTriangle(app: *App, triangle: Triangle) void {
    for (0..3) |i| {
        const pos_0 = triangle[i];
        const pos_1 = if (i < 2)
            triangle[i + 1]
        else
            triangle[0];

        const screen_x0: i32 = @trunc((@as(f32, @floatFromInt(app.render_buffer.width - 1)) * pos_0[0]));
        const screen_y0: i32 = @trunc(@as(f32, @floatFromInt(app.render_buffer.height - 1)) - (@as(f32, @floatFromInt(app.render_buffer.height - 1)) * pos_0[1]));

        const screen_x1: i32 = @trunc((@as(f32, @floatFromInt(app.render_buffer.width - 1)) * pos_1[0]));
        const screen_y1: i32 = @trunc(@as(f32, @floatFromInt(app.render_buffer.height - 1)) - (@as(f32, @floatFromInt(app.render_buffer.height - 1)) * pos_1[1]));

        drawLine(app, screen_x0, screen_y0, screen_x1, screen_y1);
    }
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
            app.render_buffer.setColor(@intCast(final_x), @intCast(y), .{ 255, 0, 0, 255 });

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
            app.render_buffer.setColor(@intCast(x), @intCast(final_y), .{ 255, 0, 0, 255 });

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
