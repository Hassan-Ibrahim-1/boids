const std = @import("std");
const engine = @import("engine");
const debug = engine.debug;
const log = debug.log;
const utils = engine.utils;
const Shader = engine.Shader;
const ComputeShader = engine.ComputeShader;
const ComputeTexture = engine.ComputeTexture;

const Boid = @import("Boid.zig");
const shapes = @import("shapes.zig");
