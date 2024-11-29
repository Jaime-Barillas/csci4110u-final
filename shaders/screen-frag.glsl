#version 330

/***** Uniforms *****/
uniform sampler2D screen_texture;
/***** Uniforms *****/

/***** Inputs *****/
in vec2 f_texcoords;
/***** Inputs *****/

out vec4 frag_color;

void main() {
    frag_color = texture(screen_texture, f_texcoords);
}
