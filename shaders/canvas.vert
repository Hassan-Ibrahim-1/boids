layout(location = 0) in vec3 a_position;
layout(location = 1) in vec3 a_normal;
layout(location = 2) in vec2 a_tex_coords;

out VS_OUT {
    vec3 normal;
    vec2 tex_coords;
} vs_out;

void main() {
    gl_Position = vec4(a_position, 1.0);
    vs_out.normal = normalize(a_normal);
    vs_out.tex_coords = a_tex_coords;
}
