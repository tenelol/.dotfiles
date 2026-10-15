// A small lightning strike on the cursor once typing stops. The shader only
// sees the latest cursor change, so "finished" means either the last change
// was a typed advance and the cursor has since sat still, or the cursor just
// went from a bar to a block (leaving Neovim insert mode). Each keystroke
// resets the clock, so nothing fires mid-burst.

const float IDLE = 0.45;
const float LEAVE_DELAY = 0.03;
const float DURATION = 0.34;
const float MAX_ADVANCE_CELLS = 1.2;
const int SEGMENTS = 7;
const int BRANCH_SEGMENTS = 3;
const float JAG = 0.32;
const float CRACKLE_RATE = 32.0;
const float CORE_WIDTH = 1.1;
const float GLOW_RADIUS = 7.0;
const float RESTRIKE = 0.09;

float hash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// Jagged point along the bolt; ends stay pinned so it always meets the cursor.
vec2 boltPoint(vec2 a, vec2 b, float t, float seed, float jag) {
    vec2 dir = b - a;
    vec2 normal = normalize(vec2(-dir.y, dir.x));
    float pin = 1.0 - pow(abs(2.0 * t - 1.0), 2.0);
    return mix(a, b, t) + normal * (hash(seed + t * 17.0) - 0.5) * jag * pin;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    if (iFocus == 0 || iCursorVisible == 0) {
        return;
    }

    float cellHeight = max(iCurrentCursor.w, 1.0);
    vec2 advance = iCurrentCursor.xy - iPreviousCursor.xy;
    bool typed = iCurrentCursorStyle == CURSORSTYLE_BAR && advance.x >= 1.0 && abs(advance.y) <= 0.5
        && advance.x <= MAX_ADVANCE_CELLS * cellHeight;
    bool leftInsert = iPreviousCursorStyle == CURSORSTYLE_BAR && iCurrentCursorStyle == CURSORSTYLE_BLOCK;
    if (!typed && !leftInsert) {
        return;
    }

    float t = iTime - iTimeCursorChange - (leftInsert ? LEAVE_DELAY : IDLE);
    if (t < 0.0 || t >= DURATION) {
        return;
    }

    // Strike from up and to the right onto the top of the cursor cell.
    vec2 target = vec2(iCurrentCursor.x + iCurrentCursor.z * 0.5, iCurrentCursor.y);
    vec2 origin = target + vec2(0.9, 1.7) * cellHeight;
    vec2 lo = min(origin, target) - GLOW_RADIUS * 3.0 - cellHeight * JAG;
    vec2 hi = max(origin, target) + GLOW_RADIUS * 3.0 + cellHeight * JAG;
    bool outside = any(lessThan(fragCoord, lo)) || any(greaterThan(fragCoord, hi));
    if (outside && length(fragCoord - target) > cellHeight * 1.5) {
        return;
    }

    // Two strikes: the main hit and a weaker re-strike, re-drawn as it crackles.
    float strike = exp(-t * 13.0) + 0.55 * step(RESTRIKE, t) * exp(-max(t - RESTRIKE, 0.0) * 15.0);
    float seed = floor(iTimeCursorChange * 97.0) + floor(t * CRACKLE_RATE) * 7.31;
    float jag = cellHeight * JAG;

    float dist = 1e4;
    vec2 prev = origin;
    for (int i = 1; i <= SEGMENTS; ++i) {
        vec2 next = boltPoint(origin, target, float(i) / float(SEGMENTS), seed, jag);
        dist = min(dist, hudSegment(fragCoord, prev, next));
        prev = next;
    }
    // One short branch peeling off the upper half.
    vec2 fork = boltPoint(origin, target, 3.0 / float(SEGMENTS), seed, jag);
    vec2 forkEnd = fork + vec2(-0.55, -0.35) * cellHeight;
    prev = fork;
    for (int i = 1; i <= BRANCH_SEGMENTS; ++i) {
        vec2 next = boltPoint(fork, forkEnd, float(i) / float(BRANCH_SEGMENTS), seed + 41.0, jag * 0.6);
        dist = min(dist, hudSegment(fragCoord, prev, next) + 0.6);
        prev = next;
    }

    float core = 1.0 - smoothstep(CORE_WIDTH * 0.5, CORE_WIDTH * 0.5 + 1.0, dist);
    float glow = exp(-dist / GLOW_RADIUS);
    // Impact flash where the bolt meets the cursor.
    float impact = exp(-length(fragCoord - target) / (cellHeight * 0.35)) * strike;

    float alpha = hudSaturate((core * 0.95 + glow * 0.35) * strike + impact * 0.4);
    vec3 color = base.rgb + (HUD_FLASH * core * 0.95 + hudAccent() * glow * 0.45) * strike + hudAccent() * impact * 0.5;
    fragColor = vec4(min(color, vec3(1.0)), max(base.a, alpha));
}
