const std = @import("std");

pub const utils = @import("utils");
pub const zm = @import("zm");

pub const math = @import("math.zig");

pub const Allocator = std.mem.Allocator;

pub const Vec = zm.Vec;
pub const Mat = zm.Mat;
pub const Quat = zm.Quat;

pub const Line = math.Line;
pub const Plane = math.Plane;
pub const Triangle = math.Triangle;

pub const Buffer = utils.Buffer;

pub const screen_edges = [4]Plane{
    .{ .{ 0, 0, 0, 1 }, .{ 1, 0, 0, 0 } },
    .{ .{ 1, 0, 0, 1 }, .{ -1, 0, 0, 0 } },
    .{ .{ 0, 0, 0, 1 }, .{ 0, 1, 0, 0 } },
    .{ .{ 0, 1, 0, 1 }, .{ 0, -1, 0, 0 } },
};

/// Errors the Renderer can return while drawing.
pub const DrawError = error{
    NoOutput,
    NoVertices,
    NoIndices,
    NoSampler,
    IncorrectDepthBufSize,
    IncorrectIndicesCount,
    IncorrectTexCoordsCount,
};

/// Back - discard triangles facing away from the player.
/// Front - discard triangles facing toward the player.
/// None - don't discard any triangles.
pub const CullMode = enum { Back, Front, None };

/// Represents a 3D software renderer.
/// Left-handed perspective.
pub const Renderer = struct {
    const Self = @This();

    /// Surface the Renderer will display to.
    surface: ?*Buffer(u8, 4) = null,

    /// Used for storing depth data.
    depth_buf: ?*Buffer(f32, 1) = null,

    /// Camera position.
    eye_pos: Vec = zm.f32x4(0, 0, 0, 1),

    /// Camera direction.
    look_dir: Vec = zm.f32x4(0, 0, 1, 0),

    /// Camera up direction.
    /// You can use this to tilt the view, like making it upside down.
    up_dir: Vec = zm.f32x4(0, 1, 0, 0),

    /// Vertical field of view.
    fovy: f32 = std.math.pi / 3.0,

    /// Render width/height aspect.
    aspect: f32 = 1,

    /// Near clipping plane distance.
    /// Anything closer to the camera than this will not be rendered.
    /// Must be larger than 0.
    /// oh also i dont like i did it this way.
    /// i should have 1 mvp matrix and then somehow extract the clipping planes from it
    /// what are the near/far values for in the perspective matrix
    /// its not like i can extract it later when i multiply it by view or model
    /// and some do stuff like adding particular mvp values together and they magically get the clipping planes
    /// fuck you
    near: f32 = 0.01,

    /// Far clipping plane distance.
    /// Anything further from the camera than this will not be rendered.
    /// Must be larger than `near`.
    far: f32 = std.math.floatMax(f32),

    /// Model vertices.
    vertices: []const Vec = &.{},

    /// Model indices.
    /// Each continuous 3 of these form a triangle.
    /// Length must be a multiple of 3.
    indices: []const usize = &.{},

    /// Model texture coordinates.
    /// These are used when mapping the texture.
    /// Length must be same as `vertices` length.
    tex_coords: []const Vec = &.{},

    /// Model transformation matrix.
    model_mat: Mat = zm.identity(),

    /// Texture to be mapped on the model.
    texture: ?*const Buffer(u8, 4) = null,

    /// Used when sampling from the texture.
    sampler: ?Sampler = null,

    /// Which triangles to cull.
    cull_mode: CullMode = .None,

    pub fn draw(self: *const Self) DrawError!void {
        if (self.surface == null and self.depth_buf == null)
            return DrawError.NoOutput;

        if (self.vertices.len == 0)
            return DrawError.NoVertices;

        if (self.indices.len == 0)
            return DrawError.NoIndices;

        if (self.surface != null and self.texture != null and self.sampler == null)
            return DrawError.NoSampler;

        if (self.surface) |surface|
            if (self.depth_buf) |depth|
                if (surface.width != depth.width or surface.height != depth.height)
                    return DrawError.IncorrectDepthBufSize;

        const view_mat = zm.lookToLh(self.eye_pos, self.look_dir, self.up_dir);
        const perspective_mat = zm.perspectiveFovLh(self.fovy, self.aspect, self.near, self.far);

        const mvp_mat = zm.mul(self.model_mat, zm.mul(view_mat, perspective_mat));

        for (0..self.indices.len / 3) |i| {
            const ind0 = self.indices[3 * i];
            const ind1 = self.indices[3 * i + 1];
            const ind2 = self.indices[3 * i + 2];

            const v0 = zm.mul(self.vertices[ind0], mvp_mat);
            const v1 = zm.mul(self.vertices[ind1], mvp_mat);
            const v2 = zm.mul(self.vertices[ind2], mvp_mat);

            const triangle = Triangle{ v0, v1, v2 };

            if (math.isTriangleCulled(triangle, self.cull_mode))
                continue;

            var tex_coords: Triangle = undefined;

            if (self.tex_coords.len > ind2) {
                tex_coords[0] = self.tex_coords[ind0];
                tex_coords[1] = self.tex_coords[ind1];
                tex_coords[2] = self.tex_coords[ind2];
            }

            const near_plane = Plane{ .{ 0, 0, self.near, 1 }, .{ 0, 0, 1, 0 } };
            const far_plane = Plane{ .{ 0, 0, self.far, 1 }, .{ 0, 0, -1, 0 } };

            var tri_0: [2]Triangle = undefined;
            var tex_0: [2]Triangle = undefined;
            const n0 = math.clipTriangle(triangle, tex_coords, near_plane, &tri_0, &tex_0);

            for (0..n0) |j| {
                var tri_1: [2]Triangle = undefined;
                var tex_1: [2]Triangle = undefined;
                const n1 = math.clipTriangle(tri_0[j], tex_0[j], far_plane, &tri_1, &tex_1);

                for (0..n1) |k| {
                    for (0..3) |x| {
                        tex_1[k][x][0] /= tri_1[k][x][3];
                        tex_1[k][x][1] /= tri_1[k][x][3];
                        tex_1[k][x][3] = 1 / tri_1[k][x][3];
                    }

                    tri_1[k] = math.screenProjTri(tri_1[k]);

                    var tri_2: [2]Triangle = undefined;
                    var tex_2: [2]Triangle = undefined;
                    const n2 = math.clipTriangle(tri_1[k], tex_1[k], screen_edges[0], &tri_2, &tex_2);

                    for (0..n2) |l| {
                        var tri_3: [2]Triangle = undefined;
                        var tex_3: [2]Triangle = undefined;
                        const n3 = math.clipTriangle(tri_2[l], tex_2[l], screen_edges[1], &tri_3, &tex_3);

                        for (0..n3) |m| {
                            var tri_4: [2]Triangle = undefined;
                            var tex_4: [2]Triangle = undefined;
                            const n4 = math.clipTriangle(tri_3[m], tex_3[m], screen_edges[2], &tri_4, &tex_4);

                            for (0..n4) |n| {
                                var tri_5: [2]Triangle = undefined;
                                var tex_5: [2]Triangle = undefined;
                                const n5 = math.clipTriangle(tri_4[n], tex_4[n], screen_edges[3], &tri_5, &tex_5);

                                for (0..n5) |o|
                                    self.drawTriangle(tri_5[o], tex_5[o]);
                            }
                        }
                    }
                }
            }
        }
    }

    fn drawTriangle(self: *const Self, tri: Triangle, tex: Triangle) void {
        const width = if (self.surface) |x|
            x.width
        else
            self.depth_buf.?.width;

        const height = if (self.surface) |x|
            x.height
        else
            self.depth_buf.?.height;

        var x0: usize = @trunc((@as(f32, @floatFromInt(width - 1)) * tri[0][0]));
        var y0: usize = @trunc(@as(f32, @floatFromInt(height - 1)) - (@as(f32, @floatFromInt(height - 1)) * tri[0][1]));

        var x1: usize = @trunc((@as(f32, @floatFromInt(width - 1)) * tri[1][0]));
        var y1: usize = @trunc(@as(f32, @floatFromInt(height - 1)) - (@as(f32, @floatFromInt(height - 1)) * tri[1][1]));

        var x2: usize = @trunc((@as(f32, @floatFromInt(width - 1)) * tri[2][0]));
        var y2: usize = @trunc(@as(f32, @floatFromInt(height - 1)) - (@as(f32, @floatFromInt(height - 1)) * tri[2][1]));

        var _u0 = tex[0][0];
        var _v0 = tex[0][1];
        var _w0 = tex[0][3];

        var _u1 = tex[1][0];
        var _v1 = tex[1][1];
        var _w1 = tex[1][3];

        var _u2 = tex[2][0];
        var _v2 = tex[2][1];
        var _w2 = tex[2][3];

        if (y0 > y1) {
            std.mem.swap(usize, &x0, &x1);
            std.mem.swap(usize, &y0, &y1);

            std.mem.swap(f32, &_u0, &_u1);
            std.mem.swap(f32, &_v0, &_v1);
            std.mem.swap(f32, &_w0, &_w1);
        }

        if (y0 > y2) {
            std.mem.swap(usize, &x0, &x2);
            std.mem.swap(usize, &y0, &y2);

            std.mem.swap(f32, &_u0, &_u2);
            std.mem.swap(f32, &_v0, &_v2);
            std.mem.swap(f32, &_w0, &_w2);
        }

        if (y1 > y2) {
            std.mem.swap(usize, &x1, &x2);
            std.mem.swap(usize, &y1, &y2);

            std.mem.swap(f32, &_u1, &_u2);
            std.mem.swap(f32, &_v1, &_v2);
            std.mem.swap(f32, &_w1, &_w2);
        }

        var dx0 = @as(i32, @intCast(x1)) - @as(i32, @intCast(x0));
        var dy0 = y1 - y0;

        var du0 = _u1 - _u0;
        var dv0 = _v1 - _v0;
        var dw0 = _w1 - _w0;

        const dx1 = @as(i32, @intCast(x2)) - @as(i32, @intCast(x0));
        const dy1 = y2 - y0;

        const du1 = _u2 - _u0;
        const dv1 = _v2 - _v0;
        const dw1 = _w2 - _w0;

        var dax_step: f32 = 0;
        var dbx_step: f32 = 0;

        var du0_step: f32 = 0;
        var dv0_step: f32 = 0;
        var dw0_step: f32 = 0;

        var du1_step: f32 = 0;
        var dv1_step: f32 = 0;
        var dw1_step: f32 = 0;

        if (dy0 != 0) {
            dax_step = @as(f32, @floatFromInt(dx0)) / @as(f32, @floatFromInt(dy0));

            du0_step = du0 / @as(f32, @floatFromInt(dy0));
            dv0_step = dv0 / @as(f32, @floatFromInt(dy0));
            dw0_step = dw0 / @as(f32, @floatFromInt(dy0));
        }

        if (dy1 != 0) {
            dbx_step = @as(f32, @floatFromInt(dx1)) / @as(f32, @floatFromInt(dy1));

            du1_step = du1 / @as(f32, @floatFromInt(dy1));
            dv1_step = dv1 / @as(f32, @floatFromInt(dy1));
            dw1_step = dw1 / @as(f32, @floatFromInt(dy1));
        }

        if (dy0 != 0) {
            for (y0..y1) |y| {
                const y_diff = @as(f32, @floatFromInt(y - y0));
                var ax: usize = @trunc(@as(f32, @floatFromInt(x0)) + y_diff * dax_step);
                var bx: usize = @trunc(@as(f32, @floatFromInt(x0)) + y_diff * dbx_step);

                var tex_u0 = _u0 + y_diff * du0_step;
                var tex_v0 = _v0 + y_diff * dv0_step;
                var tex_w0 = _w0 + y_diff * dw0_step;

                var tex_u1 = _u0 + y_diff * du1_step;
                var tex_v1 = _v0 + y_diff * dv1_step;
                var tex_w1 = _w0 + y_diff * dw1_step;

                if (ax > bx) {
                    std.mem.swap(usize, &ax, &bx);

                    std.mem.swap(f32, &tex_u0, &tex_u1);
                    std.mem.swap(f32, &tex_v0, &tex_v1);
                    std.mem.swap(f32, &tex_w0, &tex_w1);
                }

                var t: f32 = 0;
                const t_step = 1 / @as(f32, @floatFromInt(bx - ax));

                for (ax..bx) |x| {
                    const tex_u = zm.lerpV(tex_u0, tex_u1, t);
                    const tex_v = zm.lerpV(tex_v0, tex_v1, t);
                    const tex_w = zm.lerpV(tex_w0, tex_w1, t);

                    const depth = if (self.depth_buf) |buf|
                        buf.getPos(x, y)
                    else
                        std.math.inf(f32);

                    if (1 / tex_w < depth) {
                        if (self.surface) |surface| {
                            const color = if (self.texture) |texture|
                                self.sampler.?.sample(texture, tex_u, tex_v, tex_w)
                            else
                                .{ 255, 0, 255, 255 };

                            surface.setPos(x, y, color);
                        }

                        if (self.depth_buf) |buf|
                            buf.setPos(x, y, 1 / tex_w);
                    }

                    t += t_step;
                }
            }
        }

        dx0 = @as(i32, @intCast(x2)) - @as(i32, @intCast(x1));
        dy0 = y2 - y1;

        du0 = _u2 - _u1;
        dv0 = _v2 - _v1;
        dw0 = _w2 - _w1;

        dax_step = 0;
        dbx_step = 0;

        du0_step = 0;
        dv0_step = 0;
        dw0_step = 0;

        if (dy0 != 0) {
            dax_step = @as(f32, @floatFromInt(dx0)) / @as(f32, @floatFromInt(dy0));

            du0_step = du0 / @as(f32, @floatFromInt(dy0));
            dv0_step = dv0 / @as(f32, @floatFromInt(dy0));
            dw0_step = dw0 / @as(f32, @floatFromInt(dy0));
        }

        if (dy1 != 0)
            dbx_step = @as(f32, @floatFromInt(dx1)) / @as(f32, @floatFromInt(dy1));

        if (dy0 != 0) {
            for (y1..y2) |y| {
                const y_diff_0 = @as(f32, @floatFromInt(y - y0));
                const y_diff_1 = @as(f32, @floatFromInt(y - y1));

                var ax: usize = @trunc(@as(f32, @floatFromInt(x1)) + y_diff_1 * dax_step);
                var bx: usize = @trunc(@as(f32, @floatFromInt(x0)) + y_diff_0 * dbx_step);

                var tex_u0 = _u1 + y_diff_1 * du0_step;
                var tex_v0 = _v1 + y_diff_1 * dv0_step;
                var tex_w0 = _w1 + y_diff_1 * dw0_step;

                var tex_u1 = _u0 + y_diff_0 * du1_step;
                var tex_v1 = _v0 + y_diff_0 * dv1_step;
                var tex_w1 = _w0 + y_diff_0 * dw1_step;

                if (ax > bx) {
                    std.mem.swap(usize, &ax, &bx);

                    std.mem.swap(f32, &tex_u0, &tex_u1);
                    std.mem.swap(f32, &tex_v0, &tex_v1);
                    std.mem.swap(f32, &tex_w0, &tex_w1);
                }

                var t: f32 = 0;
                const t_step = 1 / @as(f32, @floatFromInt(bx - ax));

                for (ax..bx) |x| {
                    const tex_u = zm.lerpV(tex_u0, tex_u1, t);
                    const tex_v = zm.lerpV(tex_v0, tex_v1, t);
                    const tex_w = zm.lerpV(tex_w0, tex_w1, t);

                    const depth = if (self.depth_buf) |buf|
                        buf.getPos(x, y)
                    else
                        std.math.inf(f32);

                    if (1 / tex_w < depth) {
                        if (self.surface) |surface| {
                            const color = if (self.texture) |texture|
                                self.sampler.?.sample(texture, tex_u, tex_v, tex_w)
                            else
                                .{ 255, 0, 255, 255 };

                            surface.setPos(x, y, color);
                        }

                        if (self.depth_buf) |buf|
                            buf.setPos(x, y, 1 / tex_w);
                    }

                    t += t_step;
                }
            }
        }
    }
};

pub const WrapMode = enum {
    Clamp,
    Repeat,
};
pub const FilterMode = enum {
    Nearest,
    Linear,
};

pub const Sampler = struct {
    const Self = @This();

    wrap_mode_u: WrapMode,
    wrap_mode_v: WrapMode,
    filter_mode: FilterMode,

    pub fn sample(self: *const Self, buf: *const Buffer(u8, 4), u: f32, v: f32, w: f32) math.RGBA {
        const sample_u = switch (self.wrap_mode_u) {
            .Clamp => std.math.clamp(u / w, 0, 1),
            .Repeat => @abs(u / w) - @floor(@abs(u / w)),
        };

        const sample_v = switch (self.wrap_mode_v) {
            .Clamp => std.math.clamp(v / w, 0, 1),
            .Repeat => @abs(v / w) - @floor(@abs(v / w)),
        };

        return switch (self.filter_mode) {
            .Nearest => buf.getPerc(sample_u, sample_v),
            .Linear => blk: {
                // the performance is really ass with this one ..,,.,.,.,.,.
                // prob should think about mipmaps

                const perc_x = sample_u * @as(f32, @floatFromInt(buf.width - 1));
                const perc_y = sample_v * @as(f32, @floatFromInt(buf.height - 1));

                const x0: usize = @trunc(perc_x);
                const y0: usize = @trunc(perc_y);

                var x1 = x0 + 1;
                var y1 = y0 + 1;

                x1 = std.math.clamp(x1, 0, buf.width - 1);
                y1 = std.math.clamp(y1, 0, buf.height - 1);

                const color_0 = buf.getPos(x0, y0);
                const color_1 = buf.getPos(x1, y0);
                const color_2 = buf.getPos(x0, y1);
                const color_3 = buf.getPos(x1, y1);

                const tx = zm.lerpInverseV(@trunc(perc_x), @ceil(perc_x), perc_x);
                const ty = zm.lerpInverseV(@trunc(perc_y), @ceil(perc_y), perc_y);

                const color_x0 = math.lerpColor(color_0, color_1, tx);
                const color_x1 = math.lerpColor(color_2, color_3, tx);

                break :blk math.lerpColor(color_x0, color_x1, ty);
            },
        };
    }
};
