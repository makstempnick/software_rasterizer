const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const targets = [_]std.Build.ResolvedTarget{
        b.graph.host, b.resolveTargetQuery(.{ .os_tag = .windows }),
    };

    for (targets) |target| {
        const main_exe = b.addExecutable(.{ .name = "software_rasterizer", .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .optimize = optimize,
            .target = target,
        }) });

        b.installArtifact(main_exe);

        const sdl_dep = b.dependency("sdl3", .{ .optimize = optimize, .target = target, .ext_image = true });
        main_exe.root_module.addImport("sdl", sdl_dep.module("sdl3"));

        const utils_dep = b.dependency("pixel_utils", .{ .optimize = optimize, .target = target });
        main_exe.root_module.addImport("utils", utils_dep.module("pixel_utils"));

        if (target.query.os_tag == b.graph.host.query.os_tag) {
            const tests = b.addTest(.{ .name = "tests", .root_module = b.createModule(.{
                .root_source_file = b.path("src/tests.zig"),
                .optimize = optimize,
                .target = target,
            }) });

            const run_arti = b.addRunArtifact(main_exe);
            const run_step = b.step("run", "Run the executable");
            run_step.dependOn(&run_arti.step);

            const test_arti = b.addRunArtifact(tests);
            const test_step = b.step("test", "Run the tests");
            test_step.dependOn(&test_arti.step);
        }
    }
}
