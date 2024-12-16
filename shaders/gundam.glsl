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

float sdfSphere(in vec3 point, in float radius);
float sdfBox(in vec3 point, in vec3 half_size);
float sdfHorseshoe2D(in vec2 point, in vec2 curve, in float inner_radius, in vec2 arm_dimensions);
float sdfCutSphere(in vec3 point, in float radius, in float height);
float sdfVerticalCapsule(in vec3 point, in float height, in float offset);
float sdfCone(in vec3 point, in vec2 cs_angle, in float height);
float sdfVesica2D(vec2 p, float r, float d);
/***** SDF Declarations *****/

vec2 scene(in vec3 point) {
    vec2 res = vec2(FAR, UNKNOWN_MAT);

    //===== Section: Ground-Plane =====//
    float plane_y_pos = -0.8;
    float plane = point.y - plane_y_pos;
    res = vec2(plane, 1.0);
    //===== Section: Ground-Plane =====//

    //===== Section: Magnemite-Body =====//
    float body_radius = 0.15;
    float body = sdfSphere(point, 0.15);
    if (body < res.x) res = vec2(body, 2.0);
    //===== Section: Magnemite-Body =====//

    return res;
}

vec3 sceneColor(float id, vec3 point) {
    vec3 material;

    if (id < 0.5) {
        material = vec3(1.0, 0.0, 1.0);
    } else if (id < 1.5) {
        material = vec3(0.20, 0.15, 0.00);
    } else if (id < 2.5) { // Body
        material = vec3(0.05, 0.10, 0.20);
        //===== Section: Eye =====//
        vec3 npoint = normalize(point);

        float d = dot(npoint, vec3(0, 0, 1.0));
        if (d > 0.995) {
            material = vec3(0.005); // Black pupil
        } else if (d > 0.9) {
            material = vec3(0.2); // White sclera
        } else if (d > 0.89) {
            material = vec3(0.005); // Black outline
        }
        //===== Section: Eye =====//
    } else {
        material = vec3(1.0, 0.0, 1.0);
    }

    return material;
}

