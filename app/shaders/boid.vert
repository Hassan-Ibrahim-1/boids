#version 460 core

layout(location = 0) in vec3 a_position;
layout(location = 1) in mat4 a_model;
layout(location = 6) in vec4 a_color;

out vec3 color;

void main() {
    gl_Position = a_model * vec4(a_position, 1.0f);
    color = a_color.rgb;
}
