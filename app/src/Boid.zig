const std = @import("std");
const Transform = engine.Transform;
const engine = @import("engine");
const debug = engine.debug;
const assert = debug.assert;
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

pub var speed: f32 = 0.01;
pub var detection_radius: f32 = 0.12;

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
        .dir = .random(-1, 1),
        .allocator = allocator,
    };
}

pub fn drawDirectionRay(self: *Self) void {
    const dir = self.dir;
    const ray = math.Ray.init(
        self.actor.transform.position,
        .fromVec2(dir),
    );
    renderer.drawRay(&ray, 0.1);
}

pub fn update(self: *Self, boids: []Boid) void {
    const tf = &self.actor.transform;

    self.dir = self.dir.sub(self.centerOfNeighbours(boids));
    const dir = self.dir;

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
        // self.dir.x = -self.dir.x;
    } else if (tf.position.x >= max.x) {
        tf.position.x = min.x;
        // self.dir.x = -self.dir.x;
    }

    if (tf.position.y <= min.y) {
        tf.position.y = max.y;
        // self.dir.y = -self.dir.y;
    } else if (tf.position.y >= max.y) {
        tf.position.y = min.y;
        // self.dir.y = -self.dir.y;
    }

    assert(!std.math.isNan(tf.position.x), "x is nan", .{});
    assert(!std.math.isNan(tf.position.y), "y is nan", .{});
}

fn averageDirection(self: *Self, boids: []Boid) Vec2 {
    var v = Vec2.zero;
    var neighbour_count: usize = 0;
    for (boids) |*boid| {
        if (self.isNeighbour(boid)) {
            v = v.add(boid.dir);
            neighbour_count += 1;
        }
    }
    if (v.nearZero()) return self.dir;
    return v.divValue(@floatFromInt(neighbour_count)).normalized();
}

fn centerOfNeighbours(self: *Self, boids: []Boid) Vec2 {
    var v = Vec2.zero;
    var neighbour_count: usize = 0;
    for (boids) |*boid| {
        if (self.isNeighbour(boid)) {
            v = v.add(
                .fromVec3(boid.actor.transform.position),
            );
            neighbour_count += 1;
        }
    }
    v = v.divValue(@floatFromInt(neighbour_count));

    log.info("v: {any}", .{v});
    return v;
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

pub fn highlightNeighbours(
    self: *Self,
    boids: []Boid,
) void {
    for (boids) |*boid| {
        if (boid.actor.id == self.actor.id) continue;
        if (self.isNeighbour(boid)) {
            boid.actor.render_item.material.color = .init(58, 121, 222);
        } else {
            boid.actor.render_item.material.color = .white;
        }
    }
}

fn isNeighbour(self: *Self, boid: *Boid) bool {
    return utils.pointInCircle(
        .fromVec3(boid.actor.transform.position),
        .fromVec3(self.actor.transform.position),
        detection_radius,
    );
}
