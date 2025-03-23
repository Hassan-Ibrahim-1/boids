const std = @import("std");
const engine = @import("engine.zig");
const log = engine.debug.log;
const math = engine.math;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;

pub fn logVec3(name: []const u8, vec: Vec3) void {
    log.info("{s}: ({d:.3}, {d:.3}, {d:.3})", .{ name, vec.x, vec.y, vec.z });
}

pub const Size = struct {
    width: u32,
    height: u32,

    pub fn init(width: u32, height: u32) Size {
        return .{
            .width = width,
            .height = height,
        };
    }
};

pub fn pointInCircle(
    p: Vec2,
    circle_center: Vec2,
    radius: f32,
) bool {
    const dx = @abs(p.x - circle_center.x);
    if (dx > radius) {
        return false;
    }
    const dy = @abs(p.y - circle_center.y);
    if (dy > radius) {
        return false;
    }
    if (dx + dy <= radius) {
        return true;
    }

    return dx * dx + dy * dy <= radius * radius;
}

// int dx = ABS(x-xo);
//   if (    dx >  R ) return FALSE;
//   int dy = ABS(y-yo);
//   if (    dy >  R ) return FALSE;
//   if ( dx+dy <= R ) return TRUE;
//   return ( dx*dx + dy*dy <= R*R );
