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

    pub fn randomPos(self: *Cell) Vec2 {
        const pos = &self.tf.position;
        const scale = &self.tf.scale;
        const x = math.randomFloat(f32, pos.x, pos.x + scale.x / 2.0);
        const y = math.randomFloat(f32, pos.y, pos.y + scale.y / 2.0);
        return .init(x, y);
    }

    pub fn contains(self: *Cell, p: Vec3) bool {
        const pos = &self.tf.position;
        const scale = &self.tf.scale;

        const left_x = pos.x - scale.x / 2.0;
        const right_x = pos.x + scale.x / 2.0;
        const up_y = pos.y + scale.y / 2.0;
        const down_y = pos.y - scale.y / 2.0;

        if (!(p.x >= left_x and p.x < right_x)) {
            return false;
        }
        if (!(p.y >= down_y and p.y < up_y)) {
            return false;
        }
        return true;
    }
};

transform: Transform,
alloc: Allocator,
cells: ArrayList(Cell),
cols: usize,
rows: usize,

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
        .cols = n_cols,
        .rows = n_rows,
    };
}

pub fn deinit(self: *Self) void {
    for (self.cells.items) |*cell| {
        cell.boids.deinit(self.alloc);
    }
    self.cells.deinit();
}

pub fn render(self: *Self) void {
    renderer.drawQuad(&previous_cell.?.tf, .red, false);

    const neighbours = self.getCellNeighbours(previous_cell_index);
    for (neighbours) |cell| {
        if (cell == null) continue;
        renderer.drawQuad(&cell.?.tf, .green, false);
    }
}

pub fn randomCell(self: *Self) *Cell {
    const idx = math.randomInt(usize, 0, self.cells.items.len);
    return &self.cells.items[idx];
}

// on update loop through all cells and check if any boid within
// them is not in the cell anymore. if it isn't then check if it is in its
// neighbours. update the cells to contain the updated boids

pub var previous_cell: ?*Cell = null;
pub var previous_cell_index: usize = 0;
pub fn update(self: *Self, selected_boid: *const Boid) void {
    const boid_pos = selected_boid.transform.position;
    if (previous_cell == null) {
        for (self.cells.items, 0..) |*cell, i| {
            if (cell.contains(boid_pos)) {
                previous_cell = cell;
                previous_cell_index = i;
            }
        }
        return;
    }

    const pcell = previous_cell.?;
    if (pcell.contains(boid_pos)) {
        return;
    }
    for (self.cells.items, 0..) |*cell, i| {
        if (cell.contains(boid_pos)) {
            previous_cell = cell;
            previous_cell_index = i;
        }
    }
}

/// [Top-left, Top, Top-right, Left, Center, Right, Bottom-left, Bottom, Bottom-right]
pub fn getCellNeighbours(self: *Self, idx: usize) [8]?*Cell {
    const row: i32 = @intCast(@divTrunc(idx, self.cols));
    const col: i32 = @intCast(idx % self.cols);
    //
    const directions = [_]Vec2{
        .init(-1, 0),
        .init(-1, 1),
        .init(0, 1),
        .init(1, 1),
        .init(1, 0),
        .init(1, -1),
        .init(0, -1),
        .init(-1, -1),
    };

    var neighbours: [8]?*Cell = undefined;

    for (directions, 0..) |d, i| {
        const dr: i32 = @intFromFloat(d.x);
        const dc: i32 = @intFromFloat(d.y);

        const neighbor_col = col + dc;
        const neighbor_row = row + dr;

        if (0 <= neighbor_row and neighbor_row < self.cells.items.len) {
            const num_cols: i32 = @intCast(self.cols);

            var neighbour_idx = neighbor_row * num_cols + neighbor_col;
            if (neighbour_idx < 0) {
                log.info("less than 0", .{});
                neighbour_idx += @intCast(self.cells.items.len);
            } else if (neighbour_idx >= self.cells.items.len) {
                neighbour_idx -= @intCast(self.cells.items.len);
            }
            neighbours[i] = &self.cells.items[@intCast(neighbour_idx)];
        } else {
            neighbours[i] = null;
        }
    }

    return neighbours;
}
