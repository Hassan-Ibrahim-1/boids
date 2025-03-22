#version 460 core

struct Material {
    vec3 color;
};

out vec4 FragColor;

uniform Material material;

void main() {
    FragColor = vec4(material.color, 1.0);
}
