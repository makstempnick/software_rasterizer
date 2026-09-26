const std = @import("std");
const zm = @import("zm");
const math = @import("math.zig");

const Allocator = std.mem.Allocator;
const Vec = zm.Vec;
const Triangle = math.Triangle;

const Self = @This();

vertices: []Vec,
indices: []usize,

pub fn init(vertices: []Vec, indices: []usize) Self {
    return .{
        .vertices = vertices,
        .indices = indices,
    };
}
pub fn deinit(self: *Self, gpa: Allocator) void {
    gpa.free(self.vertices);
    gpa.free(self.indices);
}
pub fn fromObjFile(gpa: Allocator, std_init: std.process.Init, path: []const u8) !Self {
    var vertices = try std.ArrayList(Vec).initCapacity(gpa, 128);
    var indices = try std.ArrayList(usize).initCapacity(gpa, 256);

    const dir = std.Io.Dir.cwd();
    const file = try dir.openFile(std_init.io, path, .{ .mode = .read_only });
    defer file.close(std_init.io);

    var read_buffer: [1024]u8 = undefined;
    @memset(read_buffer[0..], 0);
    var r_fs = file.reader(std_init.io, &read_buffer);
    var reader = &r_fs.interface;

    while (true) {
        const line = try reader.peekDelimiterExclusive('\n');

        if (std.mem.eql(u8, line[0..2], "v "))
            break;

        _ = try reader.takeDelimiter('\n');
    }

    while (true) {
        const line = try reader.peekDelimiterExclusive('\n');

        if (!std.mem.eql(u8, line[0..2], "v "))
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

    while (true) {
        const line = try reader.peekDelimiterExclusive('\n');

        if (std.mem.eql(u8, line[0..2], "f "))
            break;

        _ = try reader.takeDelimiter('\n');
    }

    while (true) {
        const line = try reader.peekDelimiterExclusive('\n');

        if (!std.mem.eql(u8, line[0..2], "f "))
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
    var array_indices = try gpa.alloc(usize, indices.items.len);

    @memcpy(array_vertices[0..], vertices.items[0..]);
    @memcpy(array_indices[0..], indices.items[0..]);

    vertices.deinit(gpa);
    indices.deinit(gpa);

    return .{
        .vertices = array_vertices,
        .indices = array_indices,
    };
}
