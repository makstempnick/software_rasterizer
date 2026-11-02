const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });
    const target = b.standardTargetOptions(.{});

    const sdl_dep = b.dependency("sdl3", .{ .optimize = optimize, .target = target, .ext_image = true });
    const utils_dep = b.dependency("buffer_utils", .{ .optimize = optimize });
    const zmath_dep = b.dependency("zmath", .{ .optimize = optimize });

    const root = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,

        .imports = &.{
            .{ .name = "sdl", .module = sdl_dep.module("sdl3") },
            .{ .name = "utils", .module = utils_dep.module("buffer_utils") },
            .{ .name = "zm", .module = zmath_dep.module("root") },
        },
    });

    const run_step = b.step("run", "Run the example.");

    if (b.option([]const u8, "example", "Which example to run?")) |name| {
        const example = b.addExecutable(.{ .name = name, .root_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("examples/{s}/main.zig", .{name})),
            .optimize = optimize,
            .target = target,
            .imports = &.{
                .{ .name = "renderer", .module = root },
                .{ .name = "sdl", .module = sdl_dep.module("sdl3") },
                .{ .name = "utils", .module = utils_dep.module("buffer_utils") },
                .{ .name = "zm", .module = zmath_dep.module("root") },
            },
        }) });

        // const exe_arti = b.addInstallArtifact(example, .{ .dest_dir = .{ .override = .{ .custom = name } } });
        // b.installDirectory(.{ .install_dir = .{ .custom = name }, .install_subdir = "assets", .source_dir = b.path(b.fmt("examples/{s}/assets", .{name})) });

        const run_arti = b.addRunArtifact(example);
        run_arti.addDirectoryArg2(b.path(b.fmt("examples/{s}/assets", .{name})), .{});

        run_step.dependOn(&run_arti.step);
    }
}
