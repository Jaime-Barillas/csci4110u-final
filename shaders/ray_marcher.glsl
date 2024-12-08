#version 330

/***** Constants *****/
const int   MAX_ITERATIONS = 128;
const float EPS            = 0.001;
const float CAM_DEP        = 1.5;  // Near "plane" is 1.5 units from the camera
const float FAR            = 20.0;
const float UNKNOWN_MAT    = 0.0; // Material ID of unknown/no object
const float PI             = 3.1415;
const float TAU            = 6.2831;
const int ANAGLYPH_OFF     = 0;
const int ANAGLYPH_DOUBLE  = 1;
const int ANAGLYPH_POSTPROCESS = 2;

const vec3 UP = vec3(0.0, 1.0, 0.0);
/***** Constants *****/

/***** Uniforms *****/
uniform vec3  imouse;  // .x/.y is mouse coord, .z is 1 or 0 if mouse left is down/up
uniform vec3  iresolution;
uniform float itime;
uniform float itime_delta;
uniform int ianaglyph; // 0 = off, 1 = double render.
/***** Uniforms *****/

/***** Scene Declarations *****/
vec2 scene(in vec3 point);
vec3 sceneColor(in float material, in vec3 point);
/***** Scene Declarations *****/

layout(location = 0) out vec4 frag_colour;
layout(location = 1) out vec4 iteration_colour;

// Tetrahedron Technique: https://iquilezles.org/articles/normalsSDF/
vec3 sceneNormal(in vec3 point) {
    // NOTE: If long compile times: See link above for fix.
    const float h = 0.0001;
    const vec2  k = vec2(1.0, -1.0);
    return normalize(k.xyy * scene(point + k.xyy*h).x +
                     k.yyx * scene(point + k.yyx*h).x +
                     k.yxy * scene(point + k.yxy*h).x +
                     k.xxx * scene(point + k.xxx*h).x);
}

vec3 iterationColour(in float iterations) {
    // Using oklab colour space: https://bottosson.github.io/posts/oklab/
    // Specifically, this implementation: https://www.shadertoy.com/view/WtccD7
    const vec3 low_its  = vec3(0.23, 0.191, -0.110);
    const vec3 high_its = vec3(0.90, 0.000,  0.070);

    const mat3 fwdA = mat3(
        1.0,           1.0,           1.0,
        0.3963377774, -0.1055613458, -0.0894841775,
        0.2158037573, -0.0638541728, -1.2914855480
    );
    const mat3 fwdB = mat3(
         4.0767245293, -1.2681437731, -0.0041119885,
        -3.3072168827,  2.6093323231, -0.7034763098,
         0.2307590544, -0.3411344290,  1.7068625689
    );

    float scale = iterations / MAX_ITERATIONS;
    vec3 lms = mix(low_its, high_its, scale);

    lms = fwdA * lms;
    return fwdB * (lms*lms*lms);
}

vec3 castRay(in vec3 ro, in vec3 rd) {
    float t = 0.0; // Accumulated distance.
    float m = -1.0; // Material ID.
    int i;
    for (i = 0; i < MAX_ITERATIONS; i++) {
        vec3 p = ro + t*rd;
        vec2 res = scene(p);
        m = res.y;
        if (res.x < EPS) {  // Hit a surface or inside of one.
            break;
        }

        t += res.x;
        if (t > FAR) {  // Hit the background.
            break;
        }
    }
    if (t > FAR) {
        m = -1.0;
    }

    return vec3(t, m, i);
}

void sceneLighting(in vec3 point, in vec3 ray_info, inout vec3 colour) {
    vec3 normal = sceneNormal(point);

    // Base material reasoning: https://www.youtube.com/live/Cfe5UQ-1L9Q?si=WUc39s8PI2aatbFp&t=2393
    vec3 base_material = sceneColor(ray_info.y, point);
    vec3 sun_dir       = normalize(vec3(0.8, 0.4, 0.6));

    // sun_dif: Key light amount, main light, most directional.
    // sky_dif: Field light amount (sky).
    // NOTE: sky_dif and bounce_diff is biased such that some of the light
    //       reaches around the backside of the object.
    float sun_dif     = clamp(dot(normal, sun_dir)        , 0.0, 1.0);
    float sky_dif     = clamp(0.5 + 0.5 * dot(normal,  UP), 0.0, 1.0);
    float bounce_diff = clamp(0.5 + 0.5 * dot(normal, -UP), 0.0, 1.0);
    // NOTE: p + normal * EPS offsets the ray origin to prevent self intersection.
    float sun_sha     = step(castRay(point + (normal * EPS), sun_dir).y, 0.0);

    // Key light intensity ~10, Field light (sky) ~1. See youtube video above.
    // Bounce light: https://www.youtube.com/live/Cfe5UQ-1L9Q?si=DyACc5QO-klYfaRR&t=2558
    colour  = base_material * vec3(7.0, 4.5, 3.0) * sun_dif * sun_sha;
    colour += base_material * vec3(0.5, 0.8, 0.9) * sky_dif;
    colour += base_material * vec3(0.7, 0.3, 0.2) * bounce_diff;
}

vec3 ray_dir(in vec3 ray_origin, in vec3 cam_target, in vec2 coord) {
    // Values taken directly from https://www.youtube.com/watch?v=Cfe5UQ-1L9Q&list=PL0EpikNmjs2CYUMePMGh3IjjP4tQlYqji
    vec3 forward    = normalize(cam_target - ray_origin);
    vec3 right      = normalize(cross(forward, UP));
    vec3 up         = normalize(cross(right, forward));
    vec3 rd         = normalize(coord.x * right +
                                coord.y * up    +
                                CAM_DEP * forward);
    return rd;
}

void render2D(out vec3 colour, out vec3 ray_info) {
    // Map fragment coordinates to [-1, 1].
    vec2 coord = ((2 * gl_FragCoord.xy) - iresolution.xy) / iresolution.y;

    // Values taken directly from https://www.youtube.com/watch?v=Cfe5UQ-1L9Q&list=PL0EpikNmjs2CYUMePMGh3IjjP4tQlYqji
    float cam_angle = imouse.z == 1 ? -(10.0 * imouse.x) / iresolution.x : 0.0;
    vec3 ro         = vec3(1.0 * sin(cam_angle), 0.0, 1.0 * cos(cam_angle));
    vec3 cam_target = vec3(0.0, 0.0, 0.0);
    vec3 rd         = ray_dir(ro, cam_target, coord);

    // Sky blue. Darker at the top
    colour = vec3(0.4, 0.75, 1.0) - 0.6 * coord.y; // NOTE: colour is out variable.
    colour = mix(colour, vec3(0.7, 0.75, 0.8), exp(-10.0 * rd.y));

    ray_info = castRay(ro, rd); // NOTE: ray_info is out variable.
    if (ray_info.y > 0.0) {
        vec3 point  = ro + ray_info.x*rd;
        sceneLighting(point, ray_info, colour); // NOTE: colour is inout variable.
    }
}

void render3D(out vec3 colour, out vec3 ray_info) {
    vec2 coord = ((2 * gl_FragCoord.xy) - iresolution.xy) / iresolution.y;
    float cam_angle = imouse.z == 1 ? -(10.0 * imouse.x) / iresolution.x : 0.0;
    vec3 cam_target = vec3(0.0, 0.0, 0.0);
    vec3 ro;
    vec3 rd;
    vec3 left_colour;
    vec3 right_colour;

    // Left Eye.
    ro = vec3(0.0 - 0.01, 0.0, 1.0);
    rd = ray_dir(ro, cam_target, coord);
    left_colour = vec3(0.4, 0.75, 1.0) - 0.6 * coord.y;
    left_colour = mix(left_colour, vec3(0.7, 0.75, 0.8), exp(-10.0 * rd.y));
    ray_info = castRay(ro, rd);
    if (ray_info.y > 0.0) {
        vec3 point  = ro + ray_info.x*rd;
        sceneLighting(point, ray_info, left_colour);
    }

    // Right Eye.
    ro = vec3(0.0 + 0.01, 0.0, 1.0);
    rd = ray_dir(ro, cam_target, coord);
    right_colour = vec3(0.4, 0.75, 1.0) - 0.6 * coord.y;
    right_colour = mix(right_colour, vec3(0.7, 0.75, 0.8), exp(-10.0 * rd.y));
    ray_info = castRay(ro, rd);
    if (ray_info.y > 0.0) {
        vec3 point  = ro + ray_info.x*rd;
        sceneLighting(point, ray_info, right_colour);
    }

    colour = vec3(left_colour.r, 0.0, 0.0) + vec3(0.0, right_colour.g, right_colour.b);
}

void main() {
    vec3 colour;
    vec3 ray_info;

    if (ianaglyph == ANAGLYPH_OFF) {
        render2D(colour, ray_info); // NOTE: colour & ray_info are out variables.
    } else if (ianaglyph == ANAGLYPH_DOUBLE) {
        render3D(colour, ray_info);
    }

    // Gamma correction. 0.4545 ~standard encoding for computer displays/sRGB.
    colour      = pow(colour, vec3(0.4545));
    frag_colour = vec4(colour, 1);
    iteration_colour = vec4(pow(iterationColour(ray_info.z), vec3(0.4545)), 1.0);
}

