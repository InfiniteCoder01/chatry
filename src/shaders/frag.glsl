#version 140

in vec2 frag_uv;
out vec4 color;
uniform sampler2D image;

void main() {
    color = texture(image, frag_uv);
}
