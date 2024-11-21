#version 330

/***** Inputs *****/
in vec3 vertex;
/***** Inputs *****/

void main() {
    gl_Position = vec4(vertex, 1.0);
}
