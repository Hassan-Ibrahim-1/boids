const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const name = "engine";
    const root_source_file = b.path("src/engine.zig");

    const engine = b.addModule(name, .{
        .root_source_file = root_source_file,
        .target = target,
        .optimize = optimize,
    });

    const ft_dep = b.dependency("mach_freetype", .{
        .target = target,
        .optimize = optimize,
    });

    const ft_mod = ft_dep.module("mach-freetype");
    engine.addImport("freetype", ft_mod);

    const src_files = [_][]const u8{
        "dependencies/stb_image.c",
        "dependencies/stb_perlin.c",
        "dependencies/cgltf.c",
    };

    const flags = val: {
        if (optimize == .Debug) {
            break :val [_][]const u8{
                "-g",
            };
        } else {
            break :val [_][]const u8{
                "-O3",
            };
        }
    };

    engine.addCSourceFiles(.{
        .files = &src_files,
        .flags = &flags,
    });
    engine.addIncludePath(b.path("dependencies"));

    // const cimgui_backends = b.createModule(.{
    //     .optimize = optimize,
    //     .target = target,
    //     .root_source_file = root_source_file,
    // });
    // buildImGuiBackend(cimgui_backends);
    // engine.addImport("cimgui_backends", cimgui_backends);

    engine.addLibraryPath(b.path("dependencies/glfw/lib/"));
    engine.linkSystemLibrary("glfw", .{});
    // engine.addLibraryPath(b.path("dependencies/glfw/lib"));
    // engine.linkLibrary()

    // gl
    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.6",
        .profile = .core,
        .extensions = &.{},
    });

    engine.addImport("gl", gl_bindings);

    engine.addCMacro("GLFW_INCLUDE_NONE", "1");

    buildImGuiBackend(b, engine);
    const dep_cimgui = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });
    engine.addImport("cimgui", dep_cimgui.module("cimgui"));
    engine.addCMacro("IMGUI_USE_LEGACY_CRC32_ADLER", "1");

    const clay_dep = b.dependency("zclay", .{
        .target = target,
        .optimize = optimize,
    });
    const clay_module = clay_dep.module("zclay");
    engine.addImport("clay", clay_module);

    // check
    const exe_check = b.addExecutable(.{
        .name = name,
        .root_module = engine,
    });
    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&exe_check.step);
}

fn buildImGuiBackend(b: *std.Build, mod: *std.Build.Module) void {
    mod.addIncludePath(b.path("dependencies/cimgui.zig/dcimgui/"));
    mod.addCSourceFiles(.{ .files = &.{
        "dependencies/cimgui.zig/dcimgui/backends/imgui_impl_opengl3.cpp",
        "dependencies/cimgui.zig/dcimgui/backends/dcimgui_impl_opengl3.cpp",

        "dependencies/cimgui.zig/dcimgui/backends/imgui_impl_glfw.cpp",
        "dependencies/cimgui.zig/dcimgui/backends/dcimgui_impl_glfw.cpp",
    } });
}
