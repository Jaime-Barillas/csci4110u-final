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
float sdfOpExtrude(in vec3 point, in float d, in float amount);
vec3 sdfOpTwistY(in vec3 point, in float amount);

float sdfSphere(in vec3 point, in float radius);
float sdfBox(in vec3 point, in vec3 half_size);
float sdfHorseshoe2D(in vec2 point, in vec2 curve, in float inner_radius, in vec2 arm_dimensions);
float sdfVerticalCapsule(in vec3 point, in float height, in float radius);
/***** SDF Declarations *****/
float sdCutSphere(in vec3 p, in float r, in float h )
{
  // sampling independent computations (only depend on shape)
  float w = sqrt(r*r-h*h);

  // sampling dependant computations
  vec2 q = vec2( length(p.xz), p.y );
  float s = max( (h-r)*q.x*q.x+w*w*(h+r-2.0*q.y), h*q.x-w*q.y );
  return (s<0.0) ? length(q)-r :
         (q.x<w) ? h - q.y     :
                   length(q-vec2(w,h));
}

layout(location = 0) out vec4 frag_colour;
layout(location = 1) out vec4 iteration_colour;

vec2 scene(in vec3 point) {
    vec2 res = vec2(FAR, UNKNOWN_MAT);

    // Magnemite

    //===== Section: Magnemite-Body =====//
    float body_radius = 0.15;
    float body = sdfSphere(point, body_radius);
    res = vec2(body, 1.0);
    //===== Section: Magnemite-Body =====//

    //===== Section: Magnemite-Arms =====//
    float arm_curve = 3.14 / 2; // ~90deg for both upper and lower segment -> 180deg -> U-shape.
    float arm_radius = 0.05;
    float arm_thickness = 0.02;
    float arm_length = 0.10;
    vec2  arm_len_thick = vec2(arm_length, arm_thickness);
    vec3 arm_offset = vec3(body_radius + arm_radius + arm_thickness, 0.0, 0.0);

    vec3 arm_point = point;
    // Could abs(arm_point) (also include y-coord) but may not get exact SDF.
    // See Symmetry and Bound section of: https://iquilezles.org/articles/distfunctions/
    arm_point.x = abs(arm_point.x);
    arm_point -= arm_offset;
    arm_point = vec3(-arm_point.y, arm_point.x, arm_point.z); // 90deg rotation.
    float arms2D = sdfHorseshoe2D(arm_point.xy, vec2(cos(arm_curve), sin(arm_curve)), arm_radius, arm_len_thick);
    float arms = sdfOpExtrude(point, arms2D, arm_thickness);
    if (arms < res.x) res = vec2(arms, 2.0);
    //===== Section: Magnemite-Arms =====//

    //===== Section: Magnemite-Tips =====//
    vec3 tips_point = point;
    vec3 tips_half_size = vec3(arm_thickness);
    vec3 tips_offset = vec3(
        body_radius + arm_radius + arm_length + (2 * arm_thickness),
        arm_radius + ((arm_thickness - tips_half_size.y) / 2),
        0.0
    );
    tips_point.x = abs(tips_point.x);
    if (point.x > 0) tips_point.y = -tips_point.y; // Flip right arm tips.
    //===== Section: Magnemite-Tips =====//

    //===== Section: Magnemite-Tips-Red =====//
    float tips_red = sdfBox(tips_point - tips_offset, tips_half_size);
    if (tips_red < res.x) res = vec2(tips_red, 3.0);
    //===== Section: Magnemite-Tips-Red =====//

    //===== Section: Magnemite-Tips-Blue =====//
    tips_offset.y = -tips_offset.y;
    float tips_blue = sdfBox(tips_point - tips_offset, tips_half_size);
    if (tips_blue < res.x) res = vec2(tips_blue, 4.0);
    //===== Section: Magnemite-Tips-Blue =====//

    //===== Section: Magnemite-Screw-Top =====//
    vec3 screw_half_size = vec3(0.02, body_radius*0.3, 0.02);
    float screw_twist = 100;

    vec3 screw_point = point;
    screw_point = sdfOpTwistY(screw_point, screw_twist);
    screw_point -= vec3(0.0, body_radius + screw_half_size.y - 0.01, 0.0);
    float screw_body = sdfBox(screw_point, screw_half_size) - 0.002;

    vec3 screw_head_point = point;
    screw_head_point.y -= body_radius + screw_half_size.y - 0.035;
    float screw_head = sdCutSphere(screw_head_point, 0.1, 0.08) - 0.003;

    screw_head_point = point;
    screw_head_point.y -= 0.25;
    float screw_hole1 = sdfBox(screw_head_point, vec3(0.040, 0.02, 0.013));
    float screw_hole2 = sdfBox(screw_head_point, vec3(0.013, 0.02, 0.040));
    float screw_hole = min(screw_hole1, screw_hole2);

    float screw_top = max(-screw_hole, min(screw_body, screw_head));
    if (screw_top < res.x) res = vec2(screw_top, 5.0);
    //===== Section: Magnemite-Screw-Top =====//

    //===== Section: Magnemite-Screw-Bottom-Left =====//
    vec3 screwb_half_size = vec3(0.012, body_radius*0.2, 0.012);
    vec3 screw_p = point - vec3(-body_radius/3, 0, -0.02);
    float c = cos(3.14*1/8);
    float s = sin(3.14*1/8);
    screw_p = screw_p * mat3(
         c, 0, s,
         0, 1, 0,
        -s, 0, c
    );
    c = cos(3.14*5/8);
    s = sin(3.14*5/8);
    screw_p = screw_p * mat3(
        1,  0, 0,
        0,  c, s,
        0, -s, c);

    vec3 screwb_point = screw_p;
    screwb_point = sdfOpTwistY(screwb_point, screw_twist);
    screwb_point -= vec3(0.0, body_radius + screwb_half_size.y - 0.01, 0.0);
    float screwb_body = sdfBox(screwb_point, screwb_half_size) - 0.002;

    vec3 screwb_head_point = screw_p;
    screwb_head_point.y -= body_radius + screwb_half_size.y - 0.055;
    float screwb_head = sdCutSphere(screwb_head_point, 0.09, 0.08) - 0.003;

    screwb_head_point = screw_p;
    screwb_head_point.y -= 0.215;
    float screwb_hole1 = sdfBox(screwb_head_point, vec3(0.030, 0.013, 0.010));
    float screwb_hole2 = sdfBox(screwb_head_point, vec3(0.010, 0.013, 0.030));
    float screwb_hole = min(screwb_hole1, screwb_hole2);

    float screwb_top = max(-screwb_hole, min(screwb_body, screwb_head));
    if (screwb_top < res.x) res = vec2(screwb_top, 5.0);
    //===== Section: Magnemite-Screws-Bottom-Left =====//
    //===== Section: Magnemite-Screw-Bottom-Right =====//
    screw_p = point - vec3(body_radius/3, 0, -0.02);
    c = cos(3.14*1/8);
    s = sin(3.14*1/8);
    screw_p = screw_p * mat3(
        c, 0, -s,
        0, 1,  0,
        s, 0,  c
    );
    c = cos(3.14*5/8);
    s = sin(3.14*5/8);
    screw_p = screw_p * mat3(
        1,  0, 0,
        0,  c, s,
        0, -s, c);

    screwb_point = screw_p;
    screwb_point = sdfOpTwistY(screwb_point, screw_twist);
    screwb_point -= vec3(0.0, body_radius + screwb_half_size.y - 0.01, 0.0);
    screwb_body = sdfBox(screwb_point, screwb_half_size) - 0.002;

    screwb_head_point = screw_p;
    screwb_head_point.y -= body_radius + screwb_half_size.y - 0.055;
    screwb_head = sdCutSphere(screwb_head_point, 0.09, 0.08) - 0.003;

    screwb_head_point = screw_p;
    screwb_head_point.y -= 0.215;
    screwb_hole1 = sdfBox(screwb_head_point, vec3(0.030, 0.013, 0.010));
    screwb_hole2 = sdfBox(screwb_head_point, vec3(0.010, 0.013, 0.030));
    screwb_hole = min(screwb_hole1, screwb_hole2);

    screwb_top = max(-screwb_hole, min(screwb_body, screwb_head));
    if (screwb_top < res.x) res = vec2(screwb_top, 5.0);
    //===== Section: Magnemite-Screws-Bottom-Right =====//

    //===== Section: Ground-Plane =====//
    float plane_y_pos = -0.8;
    float plane = point.y - plane_y_pos;
    if (plane < res.x) res = vec2(plane, 10.0);
    //===== Section: Ground-Plane =====//

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
    } else if (id < 1.5) { // Body
        material = vec3(0.05, 0.10, 0.20);
    } else if (id < 2.5) { // Arms
        material = vec3(0.05, 0.07, 0.10);
    } else if (id < 3.5) { // Red tips
        material = vec3(0.15, 0.02, 0.02);
    } else if (id < 4.5) { // Blue tips
        material = vec3(0.02, 0.02, 0.15);
    } else if (id < 5.5) { // Screws
        material = vec3(0.08, 0.10, 0.12);
    } else {
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
    float cam_angle = imouse.z == 1 ? (10.0 * imouse.x) / iresolution.x : 0.0;//itime;
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

    // Gamma correction. 0.4545 ~standard encoding for computer displays/sRGB.
    colour      = pow(colour, vec3(0.4545));
    frag_colour = vec4(colour, 1);
    iteration_colour = vec4(pow(iterationColour(t.z), vec3(0.4545)), 1.0);
}

