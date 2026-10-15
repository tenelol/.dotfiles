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

// Shockwave shared by the jump reticle and the focus ripple: a refracting
// ring that rolls out from the origin of `offset`, tinted with the accent.
const float HUD_WAVE_DURATION = 0.48;
const float HUD_WAVE_REACH_CELLS = 7.0;
const float HUD_WAVE_WIDTH = 16.0;
const float HUD_WAVE_STRENGTH = 12.0;

// `scale` shrinks reach, ring width and push together for smaller ripples.
float hudWaveRadius(float t, float cellHeight, float scale) {
    return HUD_WAVE_REACH_CELLS * scale * cellHeight * hudEaseOut(t / HUD_WAVE_DURATION);
}

float hudWaveRadius(float t, float cellHeight) {
    return hudWaveRadius(t, cellHeight, 1.0);
}

vec3 hudShockwave(vec3 color, vec2 uv, vec2 offset, float t, float cellHeight, float scale) {
    if (t <= 0.0 || t >= HUD_WAVE_DURATION) {
        return color;
    }
    float dist = length(offset);
    float fade = 1.0 - t / HUD_WAVE_DURATION;
    float ring = exp(-pow((dist - hudWaveRadius(t, cellHeight, scale)) / (HUD_WAVE_WIDTH * scale), 2.0));
    vec2 push = dist > 1e-3 ? offset / dist : vec2(0.0);
    vec2 warped = clamp(uv - push * ring * HUD_WAVE_STRENGTH * scale * fade / iResolution.xy, vec2(0.0), vec2(1.0));
    color = mix(color, texture(iChannel0, warped).rgb, ring * fade);
    return color + hudAccent() * ring * fade * 0.10;
}

vec3 hudShockwave(vec3 color, vec2 uv, vec2 offset, float t, float cellHeight) {
    return hudShockwave(color, uv, offset, t, cellHeight, 1.0);
}

// Flash of the impact cell, decaying from the moment of contact.
float hudCellFlash(vec2 offset, vec2 cellHalf, float t) {
    if (t <= 0.0) {
        return 0.0;
    }
    vec2 d = abs(offset) - cellHalf;
    return exp(-max(max(d.x, d.y), 0.0) * 0.25) * exp(-t * 10.0);
}

// Glyph coverage inside one cell, so effects light a single character and
// never its neighbours.
float hudGlyphMask(vec2 p, vec2 center, vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    if (max(d.x, d.y) > 0.0) {
        return 0.0;
    }
    vec3 ink = texture(iChannel0, p / iResolution.xy).rgb;
    vec3 weights = vec3(0.2126, 0.7152, 0.0722);
    return smoothstep(0.12, 0.45, dot(ink, weights) - dot(iBackgroundColor, weights));
}

// Small bloom of a glyph: its mask on a tight ring and a wider, offset ring.
float hudGlyphGlow(vec2 p, vec2 center, vec2 halfSize, float radius) {
    float glow = hudGlyphMask(p, center, halfSize) * 0.6;
    for (int i = 0; i < 8; ++i) {
        float angle = float(i) * 0.78539816;
        glow += hudGlyphMask(p + vec2(cos(angle), sin(angle)) * radius, center, halfSize) * 0.12;
        glow += hudGlyphMask(p + vec2(cos(angle + 0.3927), sin(angle + 0.3927)) * radius * 2.5, center, halfSize) * 0.06;
    }
    return hudSaturate(glow);
}
