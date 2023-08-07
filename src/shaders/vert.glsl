#version 140

uniform vec2 object_size;
uniform vec2 screen_size;

in vec2 vertex;
in vec2 uv;
in vec2 position;
out vec2 frag_uv;

void main() {
    vec2 origin = position / screen_size * 2 - 1;
    gl_Position = vec4(origin + vertex * object_size / screen_size * 2, 0.0, 1.0);
    frag_uv = uv;
}
