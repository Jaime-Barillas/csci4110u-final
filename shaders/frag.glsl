#version 330

/***** Constants *****/
const int   MAX_ITERATIONS = 128;
const float EPS            = 0.001;
const float CAM_DEP        = 1.5;  // Near "plane" is 1.5 units from the camera
const float FAR            = 20.0;
const float UNKNOWN_MAT    = 0.0; // Material ID of unknown/no object

const vec3 UP = vec3(0.0, 1.0, 0.0);
/***** Constants *****/

/***** Uniforms *****/
uniform vec3  imouse;  // .x/.y is mouse coord, .z is 1 or 0 if mouse left is down/up
uniform vec3  iresolution;
uniform float itime;
uniform float itime_delta;
/***** Uniforms *****/

/***** SDF Declarations *****/
float sdfSphere(in vec3 point, in float radius);
float sdfBox(in vec3 point, in vec3 half_size);
/***** SDF Declarations *****/

layout(location = 0) out vec4 frag_colour;
layout(location = 1) out vec4 iteration_colour;

vec2 scene(in vec3 point) {
    vec2 res = vec2(FAR, UNKNOWN_MAT);

    float d = sdfSphere(point, 0.25);
    res = vec2(d, 1.0);

    float d2 = point.y - (-0.25);
    if (d2 < res.x) res = vec2(d2, 2.0);

    float d3 = sdfBox(point - vec3(0.0, -0.0, 0.0), vec3(0.4, 0.1, 0.1));
    if (d3 < res.x) res = vec2(d3, 3.0);

    return res;
}

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

vec3 sceneColor(float id) {
    vec3 material;

    if (id < 0.5) {
        material = vec3(1.0, 0.0, 1.0);
    } else if (id < 1.5) {
        material = vec3(0.18, 0.75, 0.23);
    } else if (id < 2.5) {
        material = vec3(0.2);
    }
    else {
        material = vec3(0.05, 0.07, 0.10);
    }

    return material;
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

void main() {
    // Map fragment coordinates to [-1, 1].
    vec2 coord = ((2 * gl_FragCoord.xy) - iresolution.xy) / iresolution.y;

    // Values taken directly from https://www.youtube.com/watch?v=Cfe5UQ-1L9Q&list=PL0EpikNmjs2CYUMePMGh3IjjP4tQlYqji
    float cam_angle = imouse.z == 1 ? (10.0 * imouse.x) / iresolution.x : itime;
    vec3 ro         = vec3(1.0 * sin(cam_angle), 0.0, 1.0 * cos(cam_angle));
    vec3 cam_target = vec3(0.0, 0.0, 0.0);
    vec3 forward    = normalize(cam_target - ro);
    vec3 right      = normalize(cross(forward, UP));
    vec3 up         = normalize(cross(right, forward));
    vec3 rd         = normalize(coord.x * right +
                                coord.y * up    +
                                CAM_DEP * forward);

    // Sky blue. Darker at the top
    vec3 colour = vec3(0.4, 0.75, 1.0) - 0.6 * coord.y;
    colour      = mix(colour, vec3(0.7, 0.75, 0.8), exp(-10.0 * rd.y));

    vec3 t = castRay(ro, rd);
    if (t.y > 0.0) {
        vec3 point  = ro + t.x*rd;
        vec3 normal = sceneNormal(point);

        // Base material reasoning: https://www.youtube.com/live/Cfe5UQ-1L9Q?si=WUc39s8PI2aatbFp&t=2393
        vec3 base_material = sceneColor(t.y);
        vec3 sun_dir       = normalize(vec3(0.8, 0.4, 0.2));

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

    // Gamma correction. 0.4545 ~standard encoding for computer displays/sRGB.
    colour      = pow(colour, vec3(0.4545));
    frag_colour = vec4(colour, 1);
    iteration_colour = vec4(pow(iterationColour(t.z), vec3(0.4545)), 1.0);
}

