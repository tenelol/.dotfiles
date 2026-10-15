// Shared HUD language for the Ghostty effects, prepended to each of them by
// the Nix module: one accent color, a white lock flash, homing approach,
// a damped wobble on impact, and corner-bracket geometry.

const vec3 HUD_FLASH = vec3(1.0);

vec3 hudAccent() {
    return iPalette[4];
}

float hudSaturate(float x) {
    return clamp(x, 0.0, 1.0);
}

// Accelerates into the target like a homing reticle.
float hudHoming(float t) {
    t = hudSaturate(t);
    return t * t;
}

float hudEaseOut(float t) {
    t = 1.0 - hudSaturate(t);
    return 1.0 - t * t * t;
}

// Ring-out after impact: starts at zero, swings, and decays.
float hudWobble(float t, float frequency, float damping) {
    return t > 0.0 ? sin(t * frequency) * exp(-t * damping) : 0.0;
}

mat2 hudRotate(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, -s, s, c);
}

vec2 hudCellCenter(vec4 cursor) {
    return cursor.xy + vec2(cursor.z, -cursor.w) * 0.5;
}

float hudSegment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float h = hudSaturate(dot(p - a, ab) / max(dot(ab, ab), 1e-4));
    return length(p - a - ab * h);
}

float hudRoundBox(vec2 p, vec2 halfSize, float radius) {
    vec2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// Coverage of four L-shaped brackets framing a box of `halfSize` around the
// origin; folding into one quadrant makes all four corners one distance test.
float hudBrackets(vec2 offset, vec2 halfSize, float arm, float width) {
    vec2 q = abs(offset);
    float d = min(
        hudSegment(q, halfSize, halfSize - vec2(arm, 0.0)),
        hudSegment(q, halfSize, halfSize - vec2(0.0, arm))
    );
    return 1.0 - smoothstep(width * 0.5, width * 0.5 + 1.2, d);
}
