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
const Mat4 = math.Mat4;
const Ray = math.Ray;
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
const ig = engine.ig;

const shapes = @import("shapes.zig");
const Boid = @import("Boid.zig");

const State = struct {
    alloc: Allocator,
    boid_shader: Shader,
    boids: ArrayList(Boid),
    draw_direction_rays: bool,

    pub fn init(self: *State) !void {
        self.alloc = engine.allocator();
        self.boids = .init(self.alloc);
        self.draw_direction_rays = true;

        self.boid_shader = try .init(
            self.alloc,
            "shaders/boid.vert",
            "shaders/boid.frag",
        );
    }

    pub fn deinit(self: *State) void {
        self.boids.deinit();
    }
};

var state: State = undefined;

fn init() !void {
    engine.camera().lock();
    engine.scene().setSkyboxHidden(true);

    try state.init();
    try shapes.init(state.alloc);

    try createBoids();
}

fn createBoids() !void {
    for (0..200) |i| {
        const name = try std.fmt.allocPrint(state.alloc, "boid {}", .{i});
        var boid = Boid.init(state.alloc, name);
        boid.actor.render_item.material.shader = &state.boid_shader;
        boid.actor.transform.position =
            .init(math.randomF32(-1, 1), math.randomF32(-1, 1), 0);
        try state.boids.append(boid);
        defer state.alloc.free(name);
    }
    state.boids.items[0].actor.render_item.material.color = .red;
}

fn update() !void {
    if (engine.cursorEnabled()) {
        ig.begin("boids");
        defer ig.end();

        _ = ig.dragFloatEx(
            "boid speed",
            &Boid.speed,
            0.01,
            null,
            null,
        );
        _ = ig.dragFloatEx(
            "detection radius",
            &Boid.detection_radius,
            0.01,
            null,
            null,
        );
        _ = ig.checkBox(
            "draw direction rays",
            &state.draw_direction_rays,
        );
        ig.spacing();
    }
    for (state.boids.items) |*boid| {
        boid.update();
        if (state.draw_direction_rays) {
            boid.drawDirectionRay();
        }
    }
    const boid = &state.boids.items[0];
    boid.highlightNeighbours(state.boids);
}

fn deinit() void {
    shapes.deinit();
    state.deinit();
}

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
