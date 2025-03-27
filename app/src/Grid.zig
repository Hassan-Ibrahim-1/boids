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
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Bounds = math.Bounds;
const Scene = engine.Scene;
const shapes = @import("shapes.zig");

const Boid = @import("Boid.zig");

const Grid = @This();
const Self = Grid;

pub const Cell = struct {
    tf: Transform,
    boids: ArrayListUnmanaged(*Boid),
};

transform: Transform,
alloc: Allocator,
cells: ArrayList(Cell),

pub fn init(
    alloc: Allocator,
    tf: *const Transform,
    cell_count: usize,
) Allocator.Error!Grid {
    var f1: usize = @intFromFloat(@sqrt(@as(f32, @floatFromInt(cell_count))));
    while (cell_count % f1 != 0) {
        f1 -= 1;
    }
    const f2: usize = @divFloor(cell_count, f1);

    var n_rows: usize = 0;
    var n_cols: usize = 0;

    if (tf.scale.x > tf.scale.y) {
        n_rows = f1 - 1;
        n_cols = f2 - 1;
    } else {
        n_rows = f2 - 1;
        n_cols = f1 - 1;
    }

    var cell_tf: Transform = .{};
    cell_tf.scale.x = tf.scale.x / @as(f32, @floatFromInt(n_cols));
    cell_tf.scale.y = tf.scale.y / @as(f32, @floatFromInt(n_rows));

    // make cell go to the upper left corner
    cell_tf.position.x = (-0.5 * tf.scale.x) + tf.position.x;
    // + here to make the cell go to the right
    cell_tf.position.x += (cell_tf.scale.x / 2.0);

    // - here to make the cell go downwards - opposite of vao coordinate
    cell_tf.position.y = (0.5 * tf.scale.y) + tf.position.y;
    cell_tf.position.y -= (cell_tf.scale.y / 2.0);

    const original_xpos = cell_tf.position.x;

    var cells: ArrayList(Cell) = .init(alloc);

    // log.info("tf: {any}", .{cell_tf});
    log.info("rows: {}", .{n_rows});
    log.info("cols: {}", .{n_cols});

    for (0..n_rows) |_| {
        for (0..n_cols) |_| {
            try cells.append(.{
                .tf = cell_tf,
                .boids = .empty,
            });
            cell_tf.position.x += cell_tf.scale.x;
        }
        cell_tf.position.x = original_xpos;
        cell_tf.position.y -= cell_tf.scale.y;
    }

    return Grid{
        .alloc = alloc,
        .transform = tf.*,
        .cells = cells,
    };
}

pub fn deinit(self: *Self) void {
    for (self.cells.items) |*cell| {
        cell.boids.deinit(self.alloc);
    }
    self.cells.deinit();
}

pub fn render(self: *Grid) void {
    for (self.cells.items) |*cell| {
        renderer.drawQuad(&cell.tf, .white, false);
        // log.info("tf: {any}", .{cell.tf});
    }
}
