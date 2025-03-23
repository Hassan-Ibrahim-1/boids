const std = @import("std");
const engine = @import("engine");
const debug = engine.debug;
const log = debug.log;
const utils = engine.utils;
const Shader = engine.Shader;
const ig = engine.ig;
const renderer = engine.renderer;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Color = engine.Color;
const Mesh = engine.Mesh;
const Actor = engine.Actor;
const math = engine.math;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Bounds = math.Bounds;
const Scene = engine.Scene;
const shapes = @import("shapes.zig");

const Boid = @This();
const Self = Boid;

pub var speed: f32 = 1.0;

allocator: Allocator,
actor: *Actor,
dir: Vec2,

pub fn init(allocator: Allocator, name: []const u8) Boid {
    const actor = engine.scene().createActor(name);
    actor.transform.scale = .init(0.02, 0.03, 1.0);

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
        .dir = .init(0, 1.0),
        .allocator = allocator,
    };
}

pub fn drawDirectionRay(self: *Self) void {
    const dir = self.dir;
    const ray = math.Ray.init(self.actor.transform.position, .fromVec2(dir));
    log.info("pos: {any}, dir: {any}", .{ self.actor.transform.position, dir });
    renderer.drawRay(&ray, 0.1);
}

pub fn update(self: *Self) void {
    const tf = &self.actor.transform;

    const dir = self.dir.normalized();

    tf.rotation.z = math.toDegrees(std.math.atan(dir.y / dir.x));
    if (dir.x < 0) {
        tf.rotation.z += 90;
    } else {
        tf.rotation.z -= 90;
    }

    const v = Vec3.fromVec2(dir.mulValue(speed)).mulValue(engine.deltaTime());
    tf.position = tf.position.add(v);

    const min = Vec2.init(-1, -1);
    const max = Vec2.init(1, 1);

    if (tf.position.x <= min.x) {
        tf.position.x = max.x;

        self.dir = .random(-1, 1);
    }

    if (tf.position.y <= min.y) {
        tf.position.y = max.y;

        self.dir = .random(-1, 1);
    }

    if (tf.position.x >= max.x) {
        tf.position.x = min.x;

        self.dir = .random(-1, 1);
    }

    if (tf.position.y >= max.y) {
        tf.position.y = min.y;

        self.dir = .random(-1, 1);
    }
}

pub fn addToImGui(self: *Self) void {
    // TODO: this is horrible for performance
    const name = engine.scene().getActorName(self.actor).?;
    const dname = std.fmt.allocPrintZ(
        self.allocator,
        "{s} dir",
        .{name},
    ) catch unreachable;
    defer self.allocator.free(dname);
    _ = ig.dragVec2Ex(dname, &self.dir, 0.01, null, null);
}
