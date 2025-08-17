const std = @import("std");
const engine = @import("engine");
const Mesh = engine.Mesh;
const Vec3 = engine.math.Vec3;
const Vertex = engine.Vertex;

pub var triangle: Mesh = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    triangle = .init(allocator);
    try triangle.vertex_buffer.vertices.appendSlice(&.{
        .fromPos(.init(0.0, 0.7, 0.0)), // Top vertex (x, y, z)
        .fromPos(.init(-0.5, -0.5, 0.0)), // Bottom-left vertex (x, y, z)
        .fromPos(.init(0.5, -0.5, 0.0)), // Bottom-right vertex (x, y, z)
    });

    triangle.vertex_buffer.sendVertexData();
    triangle.createDrawCommand();
}

pub fn triangleVao() c_uint {
    return triangle.vertex_buffer.vao.?;
}

pub fn deinit() void {
    triangle.deinit();
}
