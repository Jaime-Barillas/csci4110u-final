#version 330

/***** Constants *****/
const int   MAX_ITERATIONS = 128;
const float EPS            = 0.001;
const float CAM_DEP        = 1.5;  // Near "plane" is 1.5 units from the camera
const float FAR            = 20.0;
const float UNKNOWN_MAT    = 0.0; // Material ID of unknown/no object
const float PI             = 3.1415;
const float TAU            = 6.2831;

const vec3 UP = vec3(0.0, 1.0, 0.0);
/***** Constants *****/

/***** Uniforms *****/
uniform vec3  imouse;  // .x/.y is mouse coord, .z is 1 or 0 if mouse left is down/up
uniform vec3  iresolution;
uniform float itime;
uniform float itime_delta;
/***** Uniforms *****/

/***** SDF Declarations *****/
float sdfOpExtrude(in vec3 point, in float d, in float amount);
vec3 sdfOpTwistY(in vec3 point, in float amount);
vec2 sdfOpRepeat2D(in vec2 point, in vec2 scale);
vec2 sdfOpRepeat2DClamped(in vec2 point, in vec2 scale, in vec2 limit);
float sdfOpSmoothMin(in float a, in float b, in float k) {
    k *= 4.0;
    float h = max( k-abs(a-b), 0.0 )/k;
    return min(a,b) - h*h*k*(1.0/4.0);
};

float sdfSphere(in vec3 point, in float radius);
float sdfBox(in vec3 point, in vec3 half_size);
float sdfHorseshoe2D(in vec2 point, in vec2 curve, in float inner_radius, in vec2 arm_dimensions);
float sdfCutSphere(in vec3 point, in float radius, in float height);
float sdfVerticalCapsule(in vec3 point, in float height, in float offset);
float sdfCone(in vec3 point, in vec2 cs_angle, in float height);
float sdfVesica2D(vec2 p, float r, float d);
/***** SDF Declarations *****/

vec3 pcg3d(vec3 seed) {
    uvec3 v = uvec3(seed);
    v = v * 1664525u + 1013904223u;   

    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;

    v ^= v >> 16u;

    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;

    // FIXME: 0xEFFFFFF ?????
    return (vec3(v) * (1.0 / 0xEFFFFFFF));// / (2^32-1);
}

float pcg3d_1(vec3 seed) {
    uvec3 v = uvec3(seed);
    v = v * 1664525u + 1013904223u;   

    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;

    v ^= v >> 16u;

    // FIXME: 0xEFFFFFF ?????
    return (float(v.x + (v.y * v.z)) * (1.0 / 0xEFFFFFFF));// / (2^32-1);
}

float detail(in float base, in vec3 point, in int iterations) {
    // 176/185/57
    mat3 rot = mat3(57/185.0, 0.0, -176/185.0,
                    0.0, 1.0, 0.0,
                    176/185.0, 0.0, 57/185.0);
    vec3 p = vec3(0);
    float d = base;
    for (int i = 0; i < iterations; i++) {
        point *= rot;
        rot *= rot;

        p = point;
        p.xz += 4 * pcg3d(vec3(i)).xz;
        p.y += 0.4;
        p.xz = sdfOpRepeat2D(p.xz, vec2(2, 2));
        float s = sdfSphere(p, 0.4);
        d = sdfOpSmoothMin(d, s, 0.1);
    }
    return d;
}

vec2 scene(in vec3 point) {
    vec2 res = vec2(FAR, UNKNOWN_MAT);

    //===== Section: Ground-Plane =====//
    float plane_y_pos = -0.8;
    float plane = point.y - plane_y_pos;
    res = vec2(plane, 1.0);
    //===== Section: Ground-Plane =====//

    vec3 detail_point = point + vec3(0, 0.9, 0);
    res.x = detail(res.x, detail_point, 4);

    float box = sdfBox(point, vec3(0.5, 0.2, 0.2));
    if (box < res.x) res.x = box;

    return res;
}

vec3 sceneColor(float id, vec3 point) {
    vec3 material;

    if (id < 0.5) {
        material = vec3(1.0, 0.0, 0.0);
    } else if (id < 1.5) {
        material = vec3(0.3, 0.25, 0.2);
    } else if (id < 2.5) {
        material = vec3(0.0, 1.0, 1.0);
    }

    return material;
}

