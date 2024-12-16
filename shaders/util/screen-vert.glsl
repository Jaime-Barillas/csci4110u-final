#version 330

/***** Inputs *****/
layout(location = 0) in vec3 vertex;
layout(location = 1) in vec2 v_texcoords;
/***** Inputs *****/

/***** Outputs *****/
out vec2 f_texcoords;
/***** Outputs *****/

void main() {
    gl_Position = vec4(vertex, 1.0);
    f_texcoords = v_texcoords;
}
