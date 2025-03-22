const std = @import("std");
const engine = @import("engine");
const debug = engine.debug;
const log = debug.log;
const utils = engine.utils;
const Shader = engine.Shader;
const ComputeShader = engine.ComputeShader;
const ComputeTexture = engine.ComputeTexture;
const renderer = engine.renderer;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Vec4 = math.Vec4;
const Mat4 = engine.math.Mat4;
const fs = engine.fs;
const Transform = engine.Transform;
const Camera = engine.Camera;
const VertexBuffer = engine.VertexBuffer;
const Color = engine.Color;
const Vertex = engine.Vertex;
const Mesh = engine.Mesh;
const Texture = engine.Texture;
const Actor = engine.Actor;
const Model = engine.Model;
const math = engine.math;
const gl = engine.gl;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Bounds = math.Bounds;
const Scene = engine.Scene;
const PointLight = engine.PointLight;
const shapes = @import("shapes.zig");

const Boid = @This();

actor: *Actor,
velocity: Vec2,

pub fn init(allocator: Allocator, name: []const u8) Boid {
    const actor = engine.scene().createActor(name);
    actor.transform.scale = .init(0.02, 0.07, 1.0);

    const mesh = actor.render_item.createMesh();
    mesh.* = .fromVao(allocator, shapes.triangleVao());
    mesh.draw_command = .{
        .mode = .triangles,
        .type = .draw_arrays,
        .vertex_count = 3,
        .instance_count = 0,
    };
    return Boid{
        .actor = actor,
        .velocity = .zero,
    };
}
