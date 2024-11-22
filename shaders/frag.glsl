#version 330

/***** Constants *****/
const int   MAX_ITERATIONS = 128;
const float EPS            = 0.001;
const float CAM_DEP        = 1.5;  // Near "plane" is 1.5 units from the camera
const float FAR            = 20.0;

const vec3 UP = vec3(0.0, 1.0, 0.0);
/***** Constants *****/

/***** Uniforms *****/
uniform vec3  imouse;  // .x/.y is mouse coord, .z is 1 or 0 if mouse left is down/up
uniform vec3  iresolution;
uniform float itime;
uniform float itime_delta;
/***** Uniforms *****/

out vec4 frag_colour;

float scene(in vec3 p) {
    float d = length(p) - 0.25;
    float d2 = p.y - (-0.25);
    return min(d, d2);
}

// Tetrahedron Technique: https://iquilezles.org/articles/normalsSDF/
vec3 sceneNormal(in vec3 p) {
    // NOTE: If long compile times: See link above for fix.
    const float h = 0.0001;
    const vec2  k = vec2(1.0, -1.0);
    return normalize(k.xyy * scene(p + k.xyy*h) +
                     k.yyx * scene(p + k.yyx*h) +
                     k.yxy * scene(p + k.yxy*h) +
                     k.xxx * scene(p + k.xxx*h));
}

float castRay(in vec3 ro, in vec3 rd) {
    float t = 0.0;
    for (int i = 0; i < MAX_ITERATIONS; i++) {
        vec3 p = ro + t*rd;
        float d = scene(p);
        if (d < EPS) {  // Hit a surface or inside of one.
            break;
        }

        t += d;
        if (t > FAR) {  // Hit the background.
            break;
        }
    }
    if (t > FAR) {
        t = -1.0;
    }

    return t;
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

    float t = castRay(ro, rd);
    if (t > 0.0) {
        // Base material reasoning: https://www.youtube.com/live/Cfe5UQ-1L9Q?si=WUc39s8PI2aatbFp&t=2393
        vec3 base_material = vec3(0.2);
        vec3 sun_dir       = normalize(vec3(0.8, 0.4, 0.2));

        vec3 point  = ro + t*rd;
        vec3 normal = sceneNormal(point);

        // sun_dif: Key light amount, main light, most directional.
        // sky_dif: Field light amount (sky).
        // NOTE: sky_dif and bounce_diff is biased such that some of the light
        //       reaches around the backside of the object.
        float sun_dif     = clamp(dot(normal, sun_dir)        , 0.0, 1.0);
        float sky_dif     = clamp(0.5 + 0.5 * dot(normal,  UP), 0.0, 1.0);
        float bounce_diff = clamp(0.5 + 0.5 * dot(normal, -UP), 0.0, 1.0);
        // NOTE: p + normal * EPS offsets the ray origin to prevent self intersection.
        float sun_sha     = step(castRay(point + (normal * EPS), sun_dir), 0.0);

        // Key light intensity ~10, Field light (sky) ~1. See youtube video above.
        // Bounce light: https://www.youtube.com/live/Cfe5UQ-1L9Q?si=DyACc5QO-klYfaRR&t=2558
        colour  = base_material * vec3(7.0, 4.5, 3.0) * sun_dif * sun_sha;
        colour += base_material * vec3(0.5, 0.8, 0.9) * sky_dif;
        colour += base_material * vec3(0.7, 0.3, 0.2) * bounce_diff;
    }

    // Gamma correction. 0.4545 ~standard encoding for computer displays/sRGB.
    colour      = pow(colour, vec3(0.4545));
    frag_colour = vec4(colour, 1);
}

