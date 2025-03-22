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

fn init() !void {}

fn update() !void {}

fn deinit() void {}

pub fn main() !void {
    try engine.init(&.{
        // .width = 1200,
        // .height = 680,
        .width = 3840,
        .height = 2160,
        .name = "App",
    });
    defer engine.deinit();
    engine.run(&.{
        .init = init,
        .update = update,
        .deinit = deinit,
    });
}
