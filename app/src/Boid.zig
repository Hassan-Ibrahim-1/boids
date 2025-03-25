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
const Material = engine.Material;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Bounds = math.Bounds;
const Scene = engine.Scene;
const shapes = @import("shapes.zig");

const Boid = @This();
const Self = Boid;

pub var speed: f32 = 0.37;
pub var detection_radius: f32 = 0.12;
pub var center_factor: f32 = 0.5;
pub var avoid_factor: f32 = 0.12;
pub var matching_factor: f32 = 0.5;

var _gen_id: u32 = 0;
fn generateId() u32 {
    _gen_id += 1;
    return _gen_id - 1;
}

allocator: Allocator,
transform: Transform,
material: Material,
dir: Vec2,
id: u32,

pub fn init(allocator: Allocator, name: []const u8) Boid {
    _ = name; // autofix
    return Boid{
        .transform = .{ .scale = .init(0.02, 0.03, 1.0) },
        .material = .init(allocator),
        .dir = .random(-1, 1),
        .allocator = allocator,
        .id = generateId(),
    };
}

pub fn drawDirectionRay(self: *Self) void {
    const dir = self.dir;
    const ray = math.Ray.init(
        self.transform.position,
        .fromVec2(dir),
    );
    renderer.drawRay(&ray, 0.1);
}

pub fn update(self: *Self, boids: []Boid) void {
    const tf = &self.transform;

    const center = self.centerOfNeighbours(boids);
    self.dir.x += (center.x - tf.position.x) * center_factor;
    self.dir.y += (center.y - tf.position.y) * center_factor;

    self.dir = self.dir.add(
        self.avoidNeighbours(boids).mulValue(avoid_factor),
    );

    const avgdir = self.averageDirection(boids);
    self.dir.x += (avgdir.x - self.dir.x) * matching_factor;
    self.dir.y += (avgdir.y - self.dir.y) * matching_factor;

    if (self.dir.length() > 0) {
        self.dir = self.dir.normalized();
    }
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

fn avoidNeighbours(self: *Self, boids: []Boid) Vec2 {
    var v = Vec3.zero;
    var neighbour_count: usize = 0;
    const p1 = self.transform.position;
    for (boids) |*boid| {
        if (self.isNeighbour(boid)) {
            const p2 = boid.transform.position;
            v = v.add(p1.sub(p2));
            neighbour_count += 1;
        }
    }
    return .fromVec3(v);
}

fn centerOfNeighbours(self: *Self, boids: []Boid) Vec2 {
    var v = Vec2.zero;
    var neighbour_count: usize = 0;
    for (boids) |*boid| {
        if (self.isNeighbour(boid)) {
            v = v.add(
                Vec2.fromVec3(boid.transform.position),
            );
            neighbour_count += 1;
        }
    }
    if (neighbour_count == 0) return self.dir;
    v = v.divValue(@floatFromInt(neighbour_count));

    log.info("v: {any}", .{v});
    return v;
}

pub fn addToImGui(self: *Self) void {
    _ = self; // autofix
    // const dname = std.fmt.allocPrintZ(
    //     self.allocator,
    //     "{s} dir",
    //     .{name},
    // ) catch unreachable;
    // defer self.allocator.free(dname);
    // _ = ig.dragVec2Ex(dname, &self.dir, 0.01, null, null);
}

pub fn highlightNeighbours(
    self: *Self,
    boids: []Boid,
) void {
    for (boids) |*boid| {
        if (boid.id == self.id) continue;
        if (self.isNeighbour(boid)) {
            boid.material.color = .init(58, 121, 222);
        } else {
            boid.material.color = .white;
        }
    }
}

fn isNeighbour(self: *Self, boid: *Boid) bool {
    return utils.pointInCircle(
        .fromVec3(boid.transform.position),
        .fromVec3(self.transform.position),
        detection_radius,
    );
}
