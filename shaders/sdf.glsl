float sdfSphere(in vec3 point, in float radius) {
    return length(point) - radius;
}

float sdfBox(in vec3 point, in vec3 half_size) {
    vec3 q = abs(point) - half_size; // Distance from corner.
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}
