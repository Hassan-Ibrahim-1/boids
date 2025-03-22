const std = @import("std");

pub fn build(b: *std.Build) void {
    // const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});

    const app_step = b.step("app", "Build the app module");
    const app_build = b.addSystemCommand(&.{
        "zig",
        "build",
    });
    app_build.setCwd(b.path("app"));

    const run_app_step = b.step("run", "Run the app module");
    const run_app = b.addSystemCommand(&.{ "zig", "build", "run" });
    run_app.setCwd(b.path("app"));

    app_step.dependOn(&app_build.step);
    run_app_step.dependOn(&run_app.step);

    // is there a better way to do this?
    const check_step = b.step("check", "Check if foo compiles");
    const check_app = b.addSystemCommand(&.{
        "zig",
        "build",
        "check",
    });
    check_app.setCwd(b.path("app"));
    check_step.dependOn(&check_app.step);
}
