const std = @import("std");
const engine = @import("../engine.zig");
const gl = engine.gl;
const log = engine.debug.log;
const debug = engine.debug;
const Mesh = engine.Mesh;
const assert = debug.assert;
const Allocator = std.mem.Allocator;
const Actor = engine.Actor;
const Camera = engine.Camera;
const Shader = engine.Shader;
const VertexBuffer = engine.VertexBuffer;
const Mat4 = math.Mat4;
const Material = engine.Material;
const fs = engine.fs;
const ArrayList = std.ArrayList;
const String = engine.String;
const math = engine.math;
const Mat3 = math.Mat3;
const Skybox = engine.Skybox;
const Model = engine.Model;
const Transform = engine.Transform;

// When adding a shader
// add it to the Shaders struct
// then to initShaders

const Shaders = struct {
    basic_mesh: Shader,
    basic_textured_mesh: Shader,
    light_mesh: Shader,
    light_textured_mesh: Shader,
    skybox: Shader,
    wireframe: Shader,
    line: Shader,
};

const StringHashMap = std.StringHashMap;

const State = struct {
    allocator: Allocator,
    shaders: Shaders,
    camera: *Camera,
    user_shaders: *StringHashMap(*Shader),
    cube_model: Model,
    rect_mesh: Mesh,
};

var state: State = undefined;

pub fn init(allocator: Allocator) void {
    state.allocator = allocator;
    initShaders();
    initModels();
    state.user_shaders = engine.userShaders();
}

pub fn deinit() void {
    deinitModels();
    deinitShaders();
}

pub fn initModels() void {
    state.cube_model = Model.init(
        state.allocator,
        fs.modelPath("cube.glb"),
    );
    initRect();
}

const Vertex = engine.Vertex;
fn initRect() void {
    const vertices = [_]Vertex{
        .fromPos(.init(0.5, 0.5, 0)),
        .fromPos(.init(0.5, -0.5, 0)),
        .fromPos(.init(-0.5, -0.5, 0)),
        .fromPos(.init(-0.5, 0.5, 0)),
    };

    const indices = [_]u32{
        0, 1, 3,
        1, 2, 3,
    };

    state.rect_mesh = .init(state.allocator);
    state
        .rect_mesh
        .vertex_buffer
        .vertices
        .appendSlice(vertices[0..]) catch unreachable;
    state
        .rect_mesh
        .vertex_buffer
        .indices
        .appendSlice(indices[0..]) catch unreachable;
    state.rect_mesh.createDrawCommand();
    state.rect_mesh.sendData();
}

pub fn deinitModels() void {
    state.cube_model.deinit();
}

fn initShaders() void {
    state.shaders.basic_mesh = Shader.init(
        state.allocator,
        fs.shaderPath("basic_mesh.vert"),
        fs.shaderPath("basic_mesh.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("basic_mesh", &state.shaders.basic_mesh);
    state.shaders.basic_textured_mesh = Shader.init(
        state.allocator,
        fs.shaderPath("basic_textured_mesh.vert"),
        fs.shaderPath("basic_textured_mesh.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("basic_textured_mesh", &state.shaders.basic_textured_mesh);

    state.shaders.light_mesh = Shader.init(
        state.allocator,
        fs.shaderPath("light_mesh.vert"),
        fs.shaderPath("light_mesh.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("light_mesh", &state.shaders.light_mesh);

    state.shaders.light_textured_mesh = Shader.init(
        state.allocator,
        fs.shaderPath("light_textured_mesh.vert"),
        fs.shaderPath("light_textured_mesh.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("light_textured_mesh", &state.shaders.light_textured_mesh);

    state.shaders.skybox = Shader.init(
        state.allocator,
        fs.shaderPath("skybox.vert"),
        fs.shaderPath("skybox.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("skybox", &state.shaders.skybox);

    state.shaders.wireframe = Shader.init(
        state.allocator,
        fs.shaderPath("wireframe.vert"),
        fs.shaderPath("wireframe.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("wireframe", &state.shaders.wireframe);

    state.shaders.line = Shader.init(
        state.allocator,
        fs.shaderPath("line.vert"),
        fs.shaderPath("line.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("line", &state.shaders.wireframe);
}

pub fn deinitShaders() void {
    var iter = state.user_shaders.valueIterator();
    while (iter.next()) |v| {
        v.*.deinit();
    }
}

pub fn startFrame() void {}

pub fn endFrame() void {}

pub fn render() void {
    state.camera = engine.camera();

    const view = state.camera.getViewMatrix();
    const proj = state.camera.getPerspectiveMatrix();
    setCameraMatrices(&view, &proj);

    renderActors();

    if (!engine.scene()._skybox_hidden) {
        renderSkybox(&engine.scene().skybox);
    }
}

fn setCameraMatrices(view: *const Mat4, proj: *const Mat4) void {
    // all renderer shaders get added to user_shaders in initShaders
    var iter = state.user_shaders.valueIterator();
    while (iter.next()) |v| {
        const shader = v.*;
        shader.use();
        // TODO: figure out a better way to do this
        // maybe another ArrayList of shaders that need camera matrices?
        if (shader.hasUniform("view")) {
            shader.setMat4("view", view);
        }
        if (shader.hasUniform("projection")) {
            shader.setMat4("projection", proj);
        }
    }
}

fn renderActors() void {
    const scene = engine.scene();
    var iter = scene.actors.iterator();
    if (scene.hasLights()) {
        sendLightData(&state.shaders.light_mesh);
        // sendLightData(&state.shaders.light_textured_mesh);
    }
    while (iter.next()) |actor| {
        renderActor(actor.value_ptr.*);
    }
}

pub fn renderActor(actor: *const Actor) void {
    const render_item = &actor.render_item;
    const mat = &render_item.material;
    if (render_item.hidden) return;
    const model = actor.transform.mat4();
    const scene = engine.scene();
    var shader: *Shader = undefined;
    // if (engine.wireframeEnabled()) {
    //     shader = &state.shaders.wireframe;
    //     shader.use();
    // } else
    if (mat.shader) |s| {
        shader = s;
        shader.use();
    } else {
        if (scene.hasLights()) {
            if (mat.hasDiffuseTextures()) {
                shader = &state.shaders.light_textured_mesh;
                // sendLightData calls shader.use
                sendLightData(shader);
                sendTextureData(mat, shader);
                shader.setMat3(
                    "inverse_model",
                    &model.inverse().transpose().toMat3(),
                );
                shader.setFloat("material.shininess", mat.shininess);
            } else {
                shader = &state.shaders.light_mesh;
                shader.use();
                shader.setMat3(
                    "inverse_model",
                    &model.inverse().transpose().toMat3(),
                );
                shader.setFloat("material.shininess", mat.shininess);
            }
        } else {
            if (mat.hasDiffuseTextures()) {
                shader = &state.shaders.basic_textured_mesh;
                sendTextureData(mat, shader);
            } else {
                shader = &state.shaders.basic_mesh;
                shader.use();
            }
        }
    }

    // TODO: this is pretty bad for performance i think?
    // figure out a better way to do this
    if (shader.hasUniform("model")) {
        shader.setMat4("model", &model);
    }
    if (shader.hasUniform("material.color")) {
        shader.setVec3("material.color", mat.color.clampedVec3());
    }
    for (render_item.meshes.items) |*mesh| {
        renderMesh(mesh);
    }
}

fn sendTextureData(mat: *const Material, shader: *Shader) void {
    shader.use();
    var i: usize = 0;
    while (i < mat.diffuseTextureCount()) : (i += 1) {
        mat.diffuse_textures.items[i].bindSlot(i);
        const str = std.fmt.allocPrintZ(
            state.allocator,
            "material.texture_diffuse{}",
            .{i + 1},
        ) catch unreachable;
        defer state.allocator.free(str);
        shader.setSampler(@ptrCast(str), i);
    }
    i = 0;
    while (i < mat.specularTextureCount()) : (i += 1) {
        mat.specular_textures.items[i].bindSlot(i);
        const str = std.fmt.allocPrintZ(
            state.allocator,
            "material.texture_specular{}",
            .{i + 1},
        ) catch unreachable;
        defer state.allocator.free(str);
        shader.setSampler(@ptrCast(str), i);
    }
}

pub fn sendLightData(shader: *Shader) void {
    const scene = engine.scene();
    shader.use();

    debug.checkGlError();
    shader.setVec3("view_pos", engine.camera().transform.position);
    shader.setInt("n_point_lights_used", @intCast(scene.pointLightCount()));
    shader.setInt("n_spot_lights_used", @intCast(scene.spotLightCount()));
    shader.setInt("n_dir_lights_used", @intCast(scene.dirLightCount()));

    var p_iter = scene.point_lights.iterator();
    var i: usize = 0;
    while (p_iter.next()) |light| : (i += 1) {
        const name = std.fmt.allocPrintZ(
            state.allocator,
            "point_lights[{}]",
            .{i},
        ) catch unreachable;
        defer state.allocator.free(name);
        light.value_ptr.*.sendToShader(state.allocator, name, shader);
    }

    var s_iter = scene.spot_lights.iterator();
    i = 0;
    while (s_iter.next()) |light| : (i += 1) {
        const name = std.fmt.allocPrintZ(
            state.allocator,
            "spot_lights[{}]",
            .{i},
        ) catch unreachable;
        defer state.allocator.free(name);
        light.value_ptr.*.sendToShader(state.allocator, name, shader);
    }

    var d_iter = scene.dir_lights.iterator();
    i = 0;
    while (d_iter.next()) |light| : (i += 1) {
        const name = std.fmt.allocPrintZ(
            state.allocator,
            "dir_lights[{}]",
            .{i},
        ) catch unreachable;
        defer state.allocator.free(name);
        light.value_ptr.*.sendToShader(state.allocator, name, shader);
    }
}

/// assumes a shader is in use
/// doesn't set any shader uniforms
pub fn renderMesh(mesh: *const Mesh) void {
    assert(mesh.buffersCreated(), "Mesh has no draw command", .{});
    const dc = mesh.draw_command.?;
    const mode: c_uint = @intCast(dc.mode.toInt());
    mesh.vertex_buffer.bind();
    defer mesh.vertex_buffer.unbind();
    switch (dc.type) {
        .draw_arrays => {
            gl.DrawArrays(
                mode,
                0,
                @intCast(dc.vertex_count),
            );
        },
        .draw_elements => {
            gl.DrawElements(
                mode,
                @intCast(dc.vertex_count),
                gl.UNSIGNED_INT,
                0,
            );
        },
        .draw_arrays_instanced => {
            gl.DrawArraysInstanced(
                mode,
                0,
                @intCast(dc.vertex_count),
                @intCast(dc.instance_count),
            );
        },
        .draw_elements_instanced => {
            gl.DrawElementsInstanced(
                mode,
                @intCast(dc.vertex_count),
                gl.UNSIGNED_INT,
                null,
                @intCast(dc.instance_count),
            );
        },

        // else => {
        //     log.err(
        //         "draw command type {s} not supported",
        //         .{@tagName(dc.type)},
        //     );
        // },
    }
}

fn renderSkybox(skybox: *Skybox) void {
    assert(skybox.loaded(), "skybox not loaded", .{});

    if (engine.wireframeEnabled()) {
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL);
    }

    const shader = &state.shaders.skybox;
    shader.use();
    gl.ActiveTexture(gl.TEXTURE0);
    shader.setInt("skybox", 0);
    shader.setMat4(
        "view",
        &engine
            .camera()
            .getViewMatrix()
            .toMat3()
            .toMat4(),
    );
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, skybox.handle);

    gl.DepthFunc(gl.LEQUAL);
    defer gl.DepthFunc(gl.LESS);

    const mesh = state.cube_model.meshes.items[0];
    renderMesh(&mesh);

    if (engine.wireframeEnabled()) {
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    }
}

pub fn cubeModel() *Model {
    return &state.cube_model;
}

pub fn rectMesh() *Mesh {
    return &state.rect_mesh;
}

pub fn getCameraMatrices() struct { proj: Mat4, view: Mat4 } {
    return .{
        .proj = state.camera.getPerspectiveMatrix(),
        .view = state.camera.getViewMatrix(),
    };
}

pub fn drawRay(ray: *const math.Ray, t: f32) void {
    const p1 = ray.origin;
    const p2 = ray.at(t);

    var vb = VertexBuffer.init(state.allocator);
    defer vb.deinit();
    vb.vertices.appendSlice(&.{
        .fromPos(p1),
        .fromPos(p2),
    }) catch unreachable;
    vb.sendVertexData();

    vb.bind();
    defer vb.unbind();

    state.shaders.line.use();
    gl.DrawArrays(gl.LINES, 0, 2);
}

const Color = engine.Color;
pub fn drawQuad(tf: *const Transform, color: Color) void {
    const shader = &state.shaders.basic_mesh;
    shader.use();
    shader.setMat4("model", &tf.mat4());
    shader.setVec3("material.color", color.clampedVec3());
    renderMesh(&state.rect_mesh);
}
