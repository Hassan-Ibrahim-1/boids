#version 460 core

out vec4 FragColor;

in VS_OUT {
    vec3 normal;
    vec2 tex_coords;
} fs_in;

uniform sampler2D screen_texture;

void main() {
    vec3 color = vec3(texture(screen_texture, fs_in.tex_coords));
    FragColor = vec4(color, 1.0);
}
