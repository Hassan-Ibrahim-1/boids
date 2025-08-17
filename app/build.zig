const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const name = "App";
    const root_source_file = b.path("src/main.zig");

    const exe_mod = b.createModule(.{
        .root_source_file = root_source_file,
        .target = target,
        .optimize = optimize,
    });

    const engine = b.dependency("engine", .{
        .target = target,
        .optimize = optimize,
    });
    const engine_mod = engine.module("engine");
    exe_mod.addImport("engine", engine_mod);

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // check
    const exe_check = b.addExecutable(.{
        .name = name,
        .root_module = exe_mod,
    });
    // is there a better way to do this?
    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&exe_check.step); // This creates a build step. It will be visible in the `zig build --help` menu,

}
