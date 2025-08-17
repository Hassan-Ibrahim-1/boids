const std = @import("std");
const engine = @import("engine");
const gl = engine.gl;
const debug = engine.debug;
const log = debug.log;
const utils = engine.utils;
const Shader = engine.Shader;
const ComputeShader = engine.ComputeShader;
const ComputeTexture = engine.ComputeTexture;
const math = engine.math;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Vec2 = math.Vec2;
const Color = engine.Color;
const Mesh = engine.Mesh;
const renderer = engine.renderer;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Boid = @import("Boid.zig");
const shapes = @import("shapes.zig");

const State = struct {
    alloc: Allocator,
    /// contains model matrices
    /// and color
    gpu_data: ArrayList(Vec4),
    instance_vbo: c_uint,
    boids: *ArrayList(Boid),
    shader: Shader,

    pub fn init(alloc: Allocator, boids: *ArrayList(Boid)) !State {
        return State{
            .alloc = alloc,
            .gpu_data = .init(alloc),
            .boids = boids,
            .instance_vbo = 0,
            .shader = try .init(
                alloc,
                "shaders/boid.vert",
                "shaders/boid.frag",
            ),
        };
    }
    pub fn deinit(self: *State) void {
        self.shader.deinit();
        self.gpu_data.deinit();
    }
};

var state: State = undefined;

pub fn init(alloc: Allocator, boids: *ArrayList(Boid)) !void {
    state = try .init(alloc, boids);
    updateGpuData();
    initBuffers();
    createTriangleDrawCommand();
}

pub fn render() void {
    updateGpuData();
    debug.checkGlError();
    sendBoidData();
    debug.checkGlError();

    state.shader.use();
    debug.checkGlError();
    renderer.renderMesh(&shapes.triangle);
    debug.checkGlError();
}

fn createTriangleDrawCommand() void {
    const mesh = &shapes.triangle;
    const dc = &mesh.draw_command.?;
    dc.mode = .triangles;
    dc.type = .draw_arrays_instanced;
    // dc.vertex_count = mesh.vertex_buffer.vertices.items.len;
    dc.vertex_count = 3;
    dc.instance_count = state.boids.items.len;
    log.info("instance count: {}", .{dc.instance_count});
}

fn updateGpuData() void {
    state.gpu_data.clearRetainingCapacity();
    for (state.boids.items) |*boid| {
        const model = boid.transform.mat4();
        state.gpu_data.appendSlice(&model.asVec4()) catch unreachable;
        state.gpu_data.append(boid.material.color.clampedVec4()) catch unreachable;
    }
}

fn sendBoidData() void {
    const vb = &shapes.triangle.vertex_buffer;
    vb.bind();
    defer vb.unbind();

    gl.BindBuffer(gl.ARRAY_BUFFER, state.instance_vbo);
    gl.BufferSubData(
        gl.ARRAY_BUFFER,
        0,
        @as(isize, @intCast(state.gpu_data.items.len)) * @sizeOf(Vec4),
        @ptrCast(state.gpu_data.items),
    );
}

fn initBuffers() void {
    const vb = &shapes.triangle.vertex_buffer;
    vb.bind();
    defer vb.unbind();

    gl.GenBuffers(1, @ptrCast(&state.instance_vbo));
    gl.BindBuffer(gl.ARRAY_BUFFER, state.instance_vbo);

    // reserve memory
    gl.BufferData(
        gl.ARRAY_BUFFER,
        @as(isize, @intCast(state.gpu_data.items.len)) * @sizeOf(Vec4),
        null,
        gl.DYNAMIC_DRAW,
    );
    log.info("len: {}", .{state.gpu_data.items.len / 5});

    const v4s = @sizeOf(Vec4);
    const stride = 5 * v4s;

    // Model
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, stride, 0);
    gl.EnableVertexAttribArray(2);
    gl.VertexAttribPointer(2, 4, gl.FLOAT, gl.FALSE, stride, 1 * v4s);
    gl.EnableVertexAttribArray(3);
    gl.VertexAttribPointer(3, 4, gl.FLOAT, gl.FALSE, stride, 2 * v4s);
    gl.EnableVertexAttribArray(4);
    gl.VertexAttribPointer(4, 4, gl.FLOAT, gl.FALSE, stride, 3 * v4s);

    gl.VertexAttribDivisor(1, 1);
    gl.VertexAttribDivisor(2, 1);
    gl.VertexAttribDivisor(3, 1);
    gl.VertexAttribDivisor(4, 1);

    // color
    gl.EnableVertexAttribArray(6);
    gl.VertexAttribPointer(6, 4, gl.FLOAT, gl.FALSE, stride, 4 * v4s);

    gl.VertexAttribDivisor(6, 1);

    debug.checkGlError();
}

pub fn deinit() void {
    gl.DeleteBuffers(1, @ptrCast(&state.instance_vbo));
    state.deinit();
}
