#version 330

//===== Section: sdfOpExtrusion =====//
float sdfOpExtrude(in vec3 point, in float d, in float amount) {
    vec2 w = vec2(d, abs(point.z) - amount);
    return min(max(w.x,w.y),0.0) + length(max(w,0.0));
}
//===== Section: sdfOpExtrusion =====//

// See: https://iquilezles.org/articles/sdfrepetition/
vec2 sdfOpRepeatMirroredClamped(in vec2 point, in float scale, in vec2 repititions) {
    vec2 id = round(point / scale);
    id.x = clamp(id.x, -(repititions.x - 1.0), (repititions.x - 1.0));
    id.y = clamp(id.y, -(repititions.y - 0.0), (repititions.y - 1));
    vec2  r = point - (scale * id);
    vec2  m = vec2(((int(id.x)&1)==0) ? r.x : -r.x,
                   ((int(id.y)&1)==0) ? r.y : -r.y );
    return m;
}

//===== Section: sdfOpTwist =====//
vec3 sdfOpTwistY(in vec3 point, in float amount) {
    float c  = cos(amount * point.y);
    float s  = sin(amount * point.y);
    mat3 rot = mat3(
         c, 0, s,
         0, 1,  0,
        -s, 0,  c);
    //vec3 new_point = vec3(rot * point.xz, point.y);
    return rot * point;
}
//===== Section: sdfOpTwist =====//


float sdfSphere(in vec3 point, in float radius) {
    return length(point) - radius;
}

float sdfBox(in vec3 point, in vec3 half_size) {
    vec3 q = abs(point) - half_size; // Distance from corner.
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdfHorseshoe2D(in vec2 point, in vec2 curve, in float inner_radius, in vec2 arm_dimensions) {
    point.x = abs(point.x);
    float l = length(point);
    point = mat2(-curve.x, curve.y, curve.y, curve.x) * point;
    point = vec2(
        (point.y > 0.0 || point.x > 0.0) ? point.x : l * sign(-curve.x),
        (point.x > 0.0) ? point.y : l
    );
    point = vec2(point.x , abs(point.y - inner_radius)) - arm_dimensions;
    return length(max(point, 0.0)) + min(0.0, max(point.x, point.y));
}

float sdfCutSphere(in vec3 p, in float r, in float h) {
    // p = point, r = radius, h = height from top of sphere.
    // sampling independent computations (only depend on shape)
    float w = sqrt(r*r-h*h);

    // sampling dependant computations
    vec2 q = vec2( length(p.xz), p.y );
    float s = max( (h-r)*q.x*q.x+w*w*(h+r-2.0*q.y), h*q.x-w*q.y );
    return (s<0.0) ? length(q)-r :
           (q.x<w) ? h - q.y     :
                     length(q-vec2(w,h));
}

