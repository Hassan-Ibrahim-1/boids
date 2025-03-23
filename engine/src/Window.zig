const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine.zig");
const gl = @import("gl");
const glfw = engine.glfw;
const input = engine.input;
const Key = input.Key;
const Action = input.Action;
const log = engine.debug.log.Scoped(.Window);
const builtin = @import("builtin");

const Window = @This();

const WindowError = error{
    GlfwInitfailed,
    GlInitFailed,
};

allocator: Allocator,
/// don't mutate this
width: u32,
/// don't mutate this
height: u32,
name: [*:0]const u8,
/// don't mutate this. you can call functions on this. but don't
/// assign it to something else
glfw_window: *glfw.GLFWwindow,
/// don't touch this
gl_procs: *gl.ProcTable,
cursor_enabled: bool = false,

/// Assumes that glfw.init has already been called
/// this will just create a window and load gl functions
/// nothing more
pub fn init(
    allocator: Allocator,
    width: u32,
    height: u32,
    name: [*:0]const u8,
) !Window {
    const monitor = glfw.glfwGetPrimaryMonitor();
    var xscale: f32 = 0;
    var yscale: f32 = 0;
    glfw.glfwGetMonitorContentScale(
        monitor,
        @ptrCast(&xscale),
        @ptrCast(&yscale),
    );
    const window = glfw.glfwCreateWindow(
        @intFromFloat(@as(f32, @floatFromInt(width)) * xscale),
        @intFromFloat(@as(f32, @floatFromInt(height)) * yscale),
        @ptrCast(name),
        monitor,
        null,
    ) orelse return error.GlfwInitfailed;
    // // center window
    // var monitor_width: i32 = 0;
    // var monitor_height: i32 = 0;
    // glfw.glfwGetMonitorPhysicalSize(
    //     monitor,
    //     @ptrCast(&monitor_width),
    //     @ptrCast(&monitor_height),
    // );
    // engine.debug.log.info("{d:.3}, {d:.3}", .{
    //     @as(f32, @floatFromInt(monitor_width)) * xscale,
    //     @as(f32, @floatFromInt(monitor_height)) * yscale,
    // });

    glfw.glfwSetInputMode(
        window,
        glfw.GLFW_RAW_MOUSE_MOTION,
        glfw.GLFW_TRUE,
    );

    glfw.glfwMakeContextCurrent(window);
    // glfw.makeContextCurrent(glfw_window);
    var gl_procs = try allocator.create(gl.ProcTable);
    if (!gl_procs.init(glfw.glfwGetProcAddress)) {
        return error.GlInitFailed;
    }

    gl.makeProcTableCurrent(gl_procs);

    _ = glfw.glfwSetFramebufferSizeCallback(window, framebufferSizeCallback);

    glfw.glfwFocusWindow(window);

    log.info(
        "creating window of size: {}, {}",
        .{ width, height },
    );
    gl.Viewport(0, 0, @intCast(width), @intCast(height));

    return .{
        .allocator = allocator,
        .width = width,
        .height = height,
        .name = name,
        .glfw_window = window,
        .gl_procs = gl_procs,
    };
}

pub fn deinit(self: *Window) void {
    self.allocator.destroy(self.gl_procs);
    glfw.glfwDestroyWindow(self.glfw_window);
    glfw.glfwMakeContextCurrent(null);
    gl.makeProcTableCurrent(null);
}

fn framebufferSizeCallback(
    window: ?*glfw.GLFWwindow,
    width: c_int,
    height: c_int,
) callconv(.C) void {
    _ = window;
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}

pub fn swapBuffers(self: *Window) void {
    if (builtin.os.tag == .linux) {
        // HACK:
        // there's a bug on linux where after enabling and then disabling the cursor,
        // the cursor remains visible. setting the cursor to GLFW_HIDDEN after disabling it
        // fixes that bug. doing it the other way around messes stuff up
        glfw.glfwSetInputMode(
            self.glfw_window,
            glfw.GLFW_CURSOR,
            if (self.cursor_enabled) glfw.GLFW_CURSOR_NORMAL else glfw.GLFW_CURSOR_DISABLED,
        );
    }

    glfw.glfwGetWindowSize(
        self.glfw_window,
        @ptrCast(&self.width),
        @ptrCast(&self.height),
    );

    glfw.glfwSwapBuffers(self.glfw_window);
}

pub fn shouldClose(self: *Window) bool {
    return if (glfw.glfwWindowShouldClose(self.glfw_window) != 0) ret: {
        break :ret true;
    } else ret: {
        break :ret false;
    };
}

pub fn setShouldClose(self: *Window, value: bool) void {
    glfw.glfwSetWindowShouldClose(self.glfw_window, if (value) 1 else 0);
    // self.glfw_window.setShouldClose(value);
}

pub fn getKey(self: *Window, key: Key) Action {
    return @enumFromInt(glfw.glfwGetKey(
        self.glfw_window,
        key.toCint(),
    ));
}

pub fn enableCursor(self: *Window, b: bool) void {
    self.cursor_enabled = b;
    if (builtin.os.tag != .linux) {
        glfw.glfwSetInputMode(
            self.glfw_window,
            glfw.GLFW_CURSOR,
            if (b) glfw.GLFW_CURSOR_NORMAL else glfw.GLFW_CURSOR_HIDDEN,
        );
        if (!b) {
            glfw.glfwSetInputMode(
                self.glfw_window,
                glfw.GLFW_CURSOR,
                glfw.GLFW_CURSOR_DISABLED,
            );
        }
    }
}
