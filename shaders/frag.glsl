#version 330

/***** Constants *****/
const int MAX_ITERATIONS = 64;
/***** Constants *****/

/***** Uniforms *****/
uniform vec3 imouse_delta;
uniform vec3 iresolution;
uniform float itime;
uniform float itime_delta;
/***** Uniforms *****/

out vec4 frag_colour;

void main() {
    vec3 coord = vec3(gl_FragCoord.xy / iresolution.xy, 0.0);
    float r = cos(itime) + 1.0;
    float g = cos(itime + 1.5) + 1.0;
    float b = cos(itime + 3.14) + 1.0;
    frag_colour = vec4(r, g, b, 1.0);
}

