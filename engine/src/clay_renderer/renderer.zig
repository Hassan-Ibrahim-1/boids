const std = @import("std");
const engine = @import("../engine.zig");
const cl = @import("clay");
const log = engine.debug.log;
const Allocator = std.mem.Allocator;
const Color = engine.Color;
const math = engine.math;
const Vec2 = math.Vec2;
const input = engine.input;
const text = @import("../text.zig");
const gl = @import("gl");
const Rect = @import("rect.zig");

const State = struct {
    allocator: Allocator,
    memory: []u8,
    arena: cl.Arena,
    debug_mode_enabled: bool = false,
};

var state: State = undefined;

pub fn init(allocator: Allocator) !void {
    state.allocator = allocator;
    const min_memory_size = cl.minMemorySize();
    state.debug_mode_enabled = false;
    state.memory = state.allocator.alloc(u8, min_memory_size) catch |err| {
        log.err(
            "Failed to allocate memory for clay: {s}",
            .{@errorName(err)},
        );
        return err;
    };
    state.arena = cl.createArenaWithCapacityAndMemory(state.memory);
    const window_size = engine.windowSize();
    _ = cl.initialize(
        state.arena,
        .{
            .h = @floatFromInt(window_size.height),
            .w = @floatFromInt(window_size.width),
        },
        .{},
    );
    try Rect.createRenderData(allocator);
    // cl.setMeasureTextFunction({}, renderer.measureText);

}

pub fn startFrame() void {
    const mouse_pos = input.getMousePos();
    const lmb_down = input.mouseButtonDown(.left);
    cl.setPointerState(
        .{
            .x = mouse_pos.x,
            .y = mouse_pos.y,
        },
        lmb_down,
    );

    const scroll_delta = input.getScrollDelta();
    const dt = engine.deltaTime();

    cl.updateScrollContainers(
        false,
        .{
            .x = scroll_delta.x,
            .y = scroll_delta.y,
        },
        dt,
    );

    const window_size = engine.windowSize();
    cl.setLayoutDimensions(.{
        .w = @floatFromInt(window_size.width),
        .h = @floatFromInt(window_size.height),
    });

    if (input.keyPressed(.three)) {
        state.debug_mode_enabled = !state.debug_mode_enabled;
        // cl.setDebugModeEnabled(state.debug_mode_enabled);
    }

    cl.beginLayout();
}

/// renders layout
pub fn endFrame() void {
    var render_commands = cl.endLayout();
    clayRender(&render_commands);
}

pub fn deinit() void {
    state.allocator.free(state.memory);
    Rect.destroyRenderData();
}

fn clayRender(
    render_commands: *cl.ClayArray(cl.RenderCommand),
) void {
    var i: usize = 0;
    while (i < render_commands.length) : (i += 1) {
        const render_command =
            cl.renderCommandArrayGet(render_commands, @intCast(i));
        const bounding_box = render_command.bounding_box;
        switch (render_command.command_type) {
            .none => {},
            .text => {
                const config = render_command.render_data.text;
                const text_str =
                    config.string_contents.chars[0..@intCast(config.string_contents.length)];
                const scale = @as(f32, @floatFromInt(config.font_size)) / 60.0;
                // log.info("scale: {d:.3}", .{scale});
                var v = (vecFromBoundingBox(bounding_box));
                v.y = 720 - v.y;
                // engine.utils.logVec3("pos: ", v);
                text.renderTextCentered(
                    text_str,
                    // Vec2.init(800, 600),
                    v,
                    scale,
                    colorFromArr(config.text_color),
                ) catch |err| {
                    log.err(
                        "Failed to render text '{s}': {s}",
                        .{ text_str, @errorName(err) },
                    );
                };
            },
            .scissor_start => {
                gl.Enable(gl.SCISSOR_TEST);
                gl.Scissor(
                    @intFromFloat(bounding_box.x),
                    @intFromFloat(bounding_box.y),
                    @intFromFloat(bounding_box.width),
                    @intFromFloat(bounding_box.height),
                );
            },
            .scissor_end => {
                gl.Disable(gl.SCISSOR_TEST);
            },
            .rectangle => {
                const config = render_command.render_data.rectangle;
                const radius: f32 =
                    (config.corner_radius.top_left * 2) / @min(
                        bounding_box.width,
                        bounding_box.height,
                    );
                Rect.init(
                    vecFromBoundingBox(bounding_box),
                    bounding_box.width,
                    bounding_box.height,
                    colorFromArr(config.background_color),
                    radius,
                ).render();
            },
            .border => {
                log.err("border not supported", .{});
                const config = render_command.render_data.border;
                if (config.width.left > 0) {
                    Rect.init(
                        Vec2.init(
                            @round(bounding_box.x),
                            @round(bounding_box.y + config.corner_radius.top_left),
                        ),
                        @floatFromInt(config.width.left),
                        @round(
                            bounding_box.height - config.corner_radius.top_left - config.corner_radius.bottom_left,
                        ),
                        colorFromArr(config.color),
                        0.0,
                    ).render();
                }
                if (config.width.right > 0) {
                    Rect.init(
                        Vec2.init(
                            @round(bounding_box.x + bounding_box.width - @as(
                                f32,
                                @floatFromInt(config.width.right),
                            )),
                            @round(bounding_box.y + config.corner_radius.top_right),
                        ),
                        @floatFromInt(config.width.right),
                        @round(
                            bounding_box.height - config.corner_radius.top_right - config.corner_radius.bottom_right,
                        ),
                        colorFromArr(config.color),
                        0.0,
                    ).render();
                }
                if (config.width.top > 0) {
                    Rect.init(
                        Vec2.init(
                            @round(bounding_box.x + config.corner_radius.top_left),
                            @round(bounding_box.y),
                        ),
                        @round(bounding_box.width - config.corner_radius.top_left - config.corner_radius.top_right),
                        @floatFromInt(config.width.top),
                        colorFromArr(config.color),
                        0.0,
                    ).render();
                }
                if (config.width.bottom > 0) {
                    Rect.init(
                        Vec2.init(
                            @round(bounding_box.x + config.corner_radius.bottom_left),

                            @round(bounding_box.y + bounding_box.height - @as(
                                f32,
                                @floatFromInt(config.width.bottom),
                            )),
                        ),
                        @round(
                            bounding_box.width - config.corner_radius.bottom_left - config.corner_radius.bottom_right,
                        ),
                        @floatFromInt(config.width.bottom),
                        colorFromArr(config.color),
                        0.0,
                    ).render();
                }
            },
            else => {
                log.err(
                    "Render command of type '{s}' not handled",
                    .{@tagName(render_command.command_type)},
                );
            },
        }
    }
}

fn vecFromBoundingBox(bounding_box: cl.BoundingBox) Vec2 {
    return Vec2.init(bounding_box.x, bounding_box.y);
}

fn colorFromArr(arr: [4]f32) Color {
    return Color.initAll(
        @intFromFloat(arr[0]),
        @intFromFloat(arr[1]),
        @intFromFloat(arr[2]),
        @intFromFloat(arr[3]),
    );
}
