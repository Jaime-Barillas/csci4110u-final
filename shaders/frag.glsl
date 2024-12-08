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

layout(location = 0) out vec4 frag_colour;
layout(location = 1) out vec4 iteration_colour;

// Transformation matrix for Magnemite.
mat4 magnemite_tx = mat4(1.0);
vec4 magnemite_translation = vec4(0, 0, 0, 1);

//===== Section: DrawGrass =====//
float drawGrass(in vec3 point) {
    point.y -= -0.8;

    vec3 point_r = point;
    point_r.xz = sdfOpRepeat2DClamped(point_r.xz, vec2(0.1, 0.1), vec2(1, 1));
    // Values experimentally determined.
    float grass_grouped = sdfVesica2D(point_r.xy, 0.5, 0.707) - 0.25;
    grass_grouped = sdfOpExtrude(point_r, grass_grouped, 0.02);

    vec3 point_h = point;
    point_h.x = abs(point_h.x);
    point_h.x -= 0.19;
    float grass_h = sdfVesica2D(point_h.xy, 0.5, 0.707) -0.25;
    grass_h = sdfOpExtrude(point_h, grass_h, 0.02);

    vec3 point_v = point;
    point_v.z = abs(point_v.z);
    point_v.z -= 0.19;
    float grass_v = sdfVesica2D(point_v.xy, 0.5, 0.707) -0.25;
    grass_v = sdfOpExtrude(point_v, grass_v, 0.02);

    return min(grass_grouped, min(grass_h, grass_v));
}
//===== Section: DrawGrass =====//

//===== Section: DrawTree =====//
vec2 drawTree(in vec3 point) {
    vec2 res;

    float trunk_height = 0.2;
    float trunk_radius = 0.05;
    float leaf_height = 0.25;
    float leaf_angle = PI / 3.2;

    float trunk = sdfVerticalCapsule(point, trunk_height, trunk_radius);

    vec2 sc = vec2(sin(leaf_angle), cos(leaf_angle));
    point.y -= trunk_height + leaf_height;
    float cone1 = sdfCone(point, sc, leaf_height);
    leaf_height -= 0.05;
    point.y -= leaf_height / 3;
    float cone2 = sdfCone(point, sc, leaf_height);
    leaf_height -= 0.05;
    point.y -= leaf_height / 3;
    float cone3 = sdfCone(point, sc, leaf_height);
    float leaves = min(cone1, min(cone2, cone3));

    if (trunk < leaves) {
        res = vec2(trunk, 7.0);
    } else {
        res = vec2(leaves, 8.0);
    }
    return res;
}
//===== Section: DrawTree =====//

//===== Section: DrawCloud =====//
float drawCloud(in vec3 point) {
    vec3 box_half_size = vec3(0.2, 0.03, 0.1);

    float cloud = sdfBox(point, box_half_size) - 0.02;
    return cloud;
}
//===== Section: DrawCloud =====//

vec2 scene(in vec3 point) {
    vec2 res = vec2(FAR, UNKNOWN_MAT);

    // Magnemite
    float rc = cos(itime);
    float rs = sin(itime);
    mat4 roty = mat4(
         rc,  0,  rs,  0,
         0,   1,   0,  0,
        -rs,  0,  rc,  0,
         0,   0,   0,  1
    );

    // Time ascension animation to 1 second minus 0.5 (pokemon at center screen @0.5)
    float x = fract(itime/TAU - 0.5);
    x = (x - 0.5) * 3;  // offset curve to center 0 at every 0.5 of a sec. Scale vertically too.
    x = x * x * x * x * x; // x_x quintic curve.
    magnemite_translation = vec4(0, x, 0, 1);

    magnemite_tx = roty;
    magnemite_tx[3] = -magnemite_translation;
    vec3 magnemite_point = (magnemite_tx * vec4(point, 1.0)).xyz;

    //===== Section: Magnemite-Body =====//
    float body_radius = 0.15;
    float body = sdfSphere(magnemite_point, body_radius);
    res = vec2(body, 1.0);
    //===== Section: Magnemite-Body =====//

    //===== Section: Magnemite-Arms =====//
    float arm_curve = PI / 2; // ~90deg for both upper and lower segment -> 180deg -> U-shape.
    float arm_radius = 0.05;
    float arm_thickness = 0.02;
    float arm_length = 0.10;
    vec2  arm_len_thick = vec2(arm_length, arm_thickness);
    vec3 arm_offset = vec3(body_radius + arm_radius + arm_thickness, 0.0, 0.0);

    vec3 arm_point = magnemite_point;
    // Could abs(arm_point) (also include y-coord) but may not get exact SDF.
    // See Symmetry and Bound section of: https://iquilezles.org/articles/distfunctions/
    arm_point.x = abs(arm_point.x);
    arm_point -= arm_offset;
    arm_point = vec3(-arm_point.y, arm_point.x, arm_point.z); // 90deg rotation.
    float arms2D = sdfHorseshoe2D(arm_point.xy, vec2(cos(arm_curve), sin(arm_curve)), arm_radius, arm_len_thick);
    float arms = sdfOpExtrude(magnemite_point, arms2D, arm_thickness);
    if (arms < res.x) res = vec2(arms, 2.0);
    //===== Section: Magnemite-Arms =====//

    //===== Section: Magnemite-Tips =====//
    vec3 tips_point = magnemite_point;
    vec3 tips_half_size = vec3(arm_thickness);
    vec3 tips_offset = vec3(
        body_radius + arm_radius + arm_length + (2 * arm_thickness),
        arm_radius + ((arm_thickness - tips_half_size.y) / 2),
        0.0
    );
    tips_point.x = abs(tips_point.x);
    if (magnemite_point.x > 0) tips_point.y = -tips_point.y; // Flip right arm tips.
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

    vec3 screw_point = magnemite_point;
    screw_point = sdfOpTwistY(screw_point, screw_twist);
    screw_point -= vec3(0.0, body_radius + screw_half_size.y - 0.01, 0.0);
    float screw_body = sdfBox(screw_point, screw_half_size) - 0.002;

    vec3 screw_head_point = magnemite_point;
    screw_head_point.y -= body_radius + screw_half_size.y - 0.035;
    float screw_head = sdfCutSphere(screw_head_point, 0.1, 0.08) - 0.003;

    screw_head_point = magnemite_point;
    screw_head_point.y -= 0.25;
    float screw_hole1 = sdfBox(screw_head_point, vec3(0.040, 0.013, 0.013));
    float screw_hole2 = sdfBox(screw_head_point, vec3(0.013, 0.013, 0.040));
    float screw_hole = min(screw_hole1, screw_hole2);

    float screw_top = max(-screw_hole, min(screw_body, screw_head));
    if (screw_top < res.x) res = vec2(screw_top, 5.0);
    //===== Section: Magnemite-Screw-Top =====//

    //===== Section: Magnemite-Screw-Bottom-Left =====//
    vec3 screwb_half_size = vec3(0.012, body_radius*0.2, 0.012);
    vec3 screw_p = magnemite_point - vec3(-body_radius/3, 0, -0.02);
    float c = cos(PI*1/8);
    float s = sin(PI*1/8);
    screw_p = screw_p * mat3(
         c, 0, s,
         0, 1, 0,
        -s, 0, c
    );
    c = cos(PI*5/8);
    s = sin(PI*5/8);
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
    float screwb_head = sdfCutSphere(screwb_head_point, 0.09, 0.08) - 0.003;

    screwb_head_point = screw_p;
    screwb_head_point.y -= 0.215;
    float screwb_hole1 = sdfBox(screwb_head_point, vec3(0.030, 0.013, 0.010));
    float screwb_hole2 = sdfBox(screwb_head_point, vec3(0.010, 0.013, 0.030));
    float screwb_hole = min(screwb_hole1, screwb_hole2);

    float screwb_top = max(-screwb_hole, min(screwb_body, screwb_head));
    if (screwb_top < res.x) res = vec2(screwb_top, 5.0);
    //===== Section: Magnemite-Screws-Bottom-Left =====//
    //===== Section: Magnemite-Screw-Bottom-Right =====//
    screw_p = magnemite_point - vec3(body_radius/3, 0, -0.02);
    c = cos(PI*1/8);
    s = sin(PI*1/8);
    screw_p = screw_p * mat3(
        c, 0, -s,
        0, 1,  0,
        s, 0,  c
    );
    c = cos(PI*5/8);
    s = sin(PI*5/8);
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
    screwb_head = sdfCutSphere(screwb_head_point, 0.09, 0.08) - 0.003;

    screwb_head_point = screw_p;
    screwb_head_point.y -= 0.215;
    screwb_hole1 = sdfBox(screwb_head_point, vec3(0.030, 0.013, 0.010));
    screwb_hole2 = sdfBox(screwb_head_point, vec3(0.010, 0.013, 0.030));
    screwb_hole = min(screwb_hole1, screwb_hole2);

    screwb_top = max(-screwb_hole, min(screwb_body, screwb_head));
    if (screwb_top < res.x) res = vec2(screwb_top, 5.0);
    //===== Section: Magnemite-Screws-Bottom-Right =====//

    //===== Section: Grass =====//
    float bend_factor = sin(itime/2);
    float fy = fract(point.y);
    mat3 rot = mat3(
         5/13.0,  0.0, 12/13.0,
         0.0,     1.0, 0.0,
        -12/13.0, 0.0, 5/13.0
    );

    vec3 grass_point = point;
    grass_point.x -= -fy*fy*fy * (bend_factor*bend_factor); // Bend grass
    grass_point = rot * grass_point;
    grass_point.xz = sdfOpRepeat2D(grass_point.xz, vec2(0.8, 0.8));
    float grass = drawGrass(grass_point);
    if (grass < res.x) res = vec2(grass, 6.0);
    //===== Section: Grass =====//

    //===== Section: Tree =====//
    if (point.z < -2) {
        vec3 tree_point = point;
        tree_point.y -= -0.8;
        tree_point *= 0.5;
        tree_point.xz = sdfOpRepeat2D(tree_point.xz, vec2(0.8));
        vec2 tree = drawTree(tree_point);
        tree.x /= 0.5;
        if (tree.x < res.x) res = tree;
    }
    //===== Section: Tree =====//

    //===== Section: Cloud =====//
    vec3 cloud_point = point;
    cloud_point.x -= -itime / 100;
    cloud_point.y -= 1;
    cloud_point.z -= itime / 200;
    cloud_point.xz = sdfOpRepeat2D(cloud_point.xz, vec2(3.0));
    float cloud = drawCloud(cloud_point);
    if (cloud < res.x) res = vec2(cloud, 9.0);
    //===== Section: Cloud =====//

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

vec3 sceneColor(float id, vec3 point) {
    vec3 material;

    if (id < 0.5) {
        material = vec3(1.0, 0.0, 1.0);
    } else if (id < 1.5) { // Body
        material = vec3(0.05, 0.10, 0.20);
        vec4 tp = vec4(point, 1.0) - magnemite_translation;
        tp = magnemite_tx * normalize(tp);

        //===== Section: Eye =====//
        float d = dot(tp, vec4(0, 0, 1, 0));
        if (d > 0.995) {
            material = vec3(0.005); // Black pupil
        } else if (d > 0.9) {
            material = vec3(0.2); // White sclera
        } else if (d > 0.89) {
            material = vec3(0.005); // Black outline
        }
        //===== Section: Eye =====//
    } else if (id < 2.5) { // Arms
        material = vec3(0.05, 0.07, 0.10);
    } else if (id < 3.5) { // Red tips
        material = vec3(0.15, 0.02, 0.02);
    } else if (id < 4.5) { // Blue tips
        material = vec3(0.02, 0.02, 0.15);
    } else if (id < 5.5) { // Screws
        material = vec3(0.08, 0.10, 0.12);
    } else if (id < 6.5) { // Grass
        material = vec3(0.04, 0.20, 0.02);
    } else if (id < 7.5) { // Tree
        material = vec3(0.04, 0.03, 0.00);
    } else if (id < 8.5) { // Tree leaves
        material = vec3(0.01, 0.05, 0.01);
    } else if (id < 9.5) { // Cloud
        material = vec3(0.30, 0.30, 0.30);
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
        vec3 base_material = sceneColor(t.y, point);
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

