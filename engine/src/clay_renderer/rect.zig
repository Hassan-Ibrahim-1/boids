const std = @import("std");
const engine = @import("../engine.zig");
const Color = engine.Color;
const math = engine.math;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Transform = engine.Transform;
const Allocator = std.mem.Allocator;
const log = engine.debug.log;
const debug = engine.debug;
const Shader = engine.Shader;
const fs = engine.fs;
const gl = @import("gl");

const Rect = @This();

const RenderData = struct {
    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint,
    shader: Shader,
};

var render_data: RenderData = undefined;

transform: Transform,
color: Color,
corner_radius: f32,

fn toNdc(
    pos: Vec2,
    width: f32,
    height: f32,
) Vec2 {
    return Vec2.init(
        ((2 * pos.x) / (1280)) + (width / (1280.0 * 1.0)) - 1.0,
        1.0 - (((2 * pos.y) / (720 * 1.0)) + (height / (720.0 * 1))),
    );
}

fn toNdcScale(width: f32, height: f32) Vec3 {
    // log.info("scale: {d:.3}, {d:.3}", .{ width, height });
    return Vec3.init(
        width / (1280.0 * 0.5),
        height / (720.0 * 0.5),
        1.0,
    );
}

pub fn init(
    pos: Vec2,
    width: f32,
    height: f32,
    color: Color,
    corner_radius: f32,
) Rect {
    _ = corner_radius; // autofix
    const position = Vec3.fromVec2(toNdc(pos, width, height));

    const scale = toNdcScale(width, height);
    const tf = Transform{
        .position = position,
        .scale = scale,
    };
    return Rect{
        .transform = tf,
        .color = color,
        .corner_radius = 0.01,
    };
}

/// This enables GL_DEPTH_TEST
pub fn render(self: *const Rect) void {
    debug.checkGlError();
    render_data.shader.use();
    render_data.shader.setMat4(
        "model",
        &self.transform.mat4(),
    );
    render_data.shader.setVec3(
        "material.color",
        self.color.clampedVec3(),
    );
    render_data.shader.setVec3("position", self.transform.position);
    render_data.shader.setVec2("scale", Vec2.fromVec3(self.transform.scale));
    render_data.shader.setFloat("radius", 0.00);

    const cam = engine.camera();
    render_data.shader.setMat4("view", &cam.getViewMatrix());
    render_data.shader.setMat4("projection", &cam.getPerspectiveMatrix());

    // no errors but nothing's being drawn

    debug.checkGlError();

    gl.Disable(gl.DEPTH_TEST);
    gl.BindVertexArray(render_data.vao);
    gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_BYTE, 0);
    gl.Enable(gl.DEPTH_TEST);

    debug.checkGlError();
}

// TODO: these rects should absolutely be instanced and not drawn one by one

/// Call this function before rendering any other rect
pub fn createRenderData(allocator: Allocator) !void {
    const vertices = [_]f32{
        0.5,  0.5,
        0.5,  -0.5,
        -0.5, -0.5,
        -0.5, 0.5,
    };

    const indices = [_]u8{
        0, 1, 3,
        1, 2, 3,
    };

    gl.GenVertexArrays(1, @ptrCast(&render_data.vao));
    gl.BindVertexArray(render_data.vao);
    defer gl.BindVertexArray(0);

    gl.GenBuffers(1, @ptrCast(&render_data.vbo));
    gl.BindBuffer(gl.ARRAY_BUFFER, render_data.vbo);
    // defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BufferData(
        gl.ARRAY_BUFFER,
        @sizeOf(@TypeOf(vertices)),
        &vertices,
        gl.STATIC_DRAW,
    );

    gl.GenBuffers(1, @ptrCast(&render_data.ebo));
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_data.ebo);
    gl.BufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        @sizeOf(@TypeOf(indices)),
        &indices,
        gl.STATIC_DRAW,
    );
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, @sizeOf(f32) * 2, 0);

    try initShader(allocator);

    debug.checkGlError();
}

pub fn destroyRenderData() void {
    gl.DeleteBuffers(1, @ptrCast(&render_data.vbo));
    gl.DeleteBuffers(1, @ptrCast(&render_data.ebo));
    gl.DeleteVertexArrays(1, @ptrCast(&render_data.vao));
    render_data.shader.deinit();
}

fn initShader(allocator: Allocator) !void {
    render_data.shader = Shader.init(
        allocator,
        fs.shaderPath("rect.vert"),
        fs.shaderPath("rect.frag"),
    ) catch |err| {
        log.err(
            "Failed to load rect shader: {s}",
            .{@errorName(err)},
        );
        return err;
    };
    engine.addShader("clay rect", &render_data.shader);
    debug.checkGlError();
}
