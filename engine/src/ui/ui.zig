const std = @import("std");
const renderer = @import("../clay_renderer/renderer.zig");
const engine = @import("../engine.zig");
const clay = @import("clay");

// NOTE:
// could use a stack to create and end windows
// make it an error to not close a window
// don't render immediately, render at only the last frame

pub fn createWindow(name: []const u8) void {
    _ = name; // autofix
}

pub fn endWindow() void {}

// do event handling here - window resizing, moving stuff around input
// or have an onEvent function

pub fn startFrame() void {}

// could throw an error here for not closing a window
/// renders
pub fn endFrame() void {}

pub fn onMouseEvent() void {}
pub fn onKeyboardEvent() void {}
