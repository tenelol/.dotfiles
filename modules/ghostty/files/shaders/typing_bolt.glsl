// Lightning growing out of the last typed character once typing stops. The
// shader only sees the latest cursor change, so "finished" means either the
// last change was a typed advance and the cursor has since sat still, or the
// cursor just went from a bar to a block (leaving Neovim insert mode). Each
// keystroke resets the clock, so nothing fires mid-burst.

const float IDLE = 0.25;
const float LEAVE_DELAY = 0.02;
const float DURATION = 0.36;
const float GROW = 0.07;
const float MAX_ADVANCE_CELLS = 1.2;
const int SEGMENTS = 6;
const float JAG = 0.28;
const float CRACKLE_RATE = 30.0;
const float CORE_WIDTH = 1.1;
const float GLOW_RADIUS = 6.0;
const float RESTRIKE = 0.11;

float hash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// Jagged point along a bolt from `a` to `b`; the root stays pinned to the glyph.
vec2 boltPoint(vec2 a, vec2 b, float t, float seed, float jag) {
    vec2 dir = b - a;
    vec2 normal = normalize(vec2(-dir.y, dir.x));
    return mix(a, b, t) + normal * (hash(seed + t * 17.0) - 0.5) * jag * sin(t * 3.14159265);
}

// Distance to a bolt drawn only up to `grow` of its length, so it extends
// from the root instead of appearing all at once.
float boltDistance(vec2 p, vec2 a, vec2 b, float grow, float seed, float jag) {
    float dist = 1e4;
    vec2 prev = a;
    for (int i = 1; i <= SEGMENTS; ++i) {
        float t0 = float(i - 1) / float(SEGMENTS);
        float t1 = float(i) / float(SEGMENTS);
        if (t0 >= grow) {
            break;
        }
        vec2 next = boltPoint(a, b, t1, seed, jag);
        vec2 tip = t1 <= grow ? next : mix(prev, next, (grow - t0) / (t1 - t0));
        dist = min(dist, hudSegment(p, prev, tip));
        prev = next;
    }
    return dist;
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

    // The source glyph: the cell the bar just left, or the block's own cell
    // (Neovim's Esc parks the block on the last typed character).
    vec2 cellHalf = typed ? vec2(advance.x, cellHeight) * 0.5 : iCurrentCursor.zw * 0.5;
    vec2 cell = typed ? vec2(iPreviousCursor.x, iPreviousCursor.y - cellHeight) + cellHalf : hudCellCenter(iCurrentCursor);
    vec2 local = fragCoord - cell;
    if (abs(local.x) > cellHeight * 2.0 || local.y < -cellHalf.y - GLOW_RADIUS * 2.0 || local.y > cellHeight * 2.4) {
        return;
    }

    float strike = exp(-t * 11.0) + 0.5 * step(RESTRIKE, t) * exp(-max(t - RESTRIKE, 0.0) * 14.0);
    float grow = hudEaseOut(t / GROW);
    float seed = floor(iTimeCursorChange * 97.0) + floor(t * CRACKLE_RATE) * 7.31;
    float jag = cellHeight * JAG;

    // Two bolts leave the top of the glyph, up-right and a shorter one up-left.
    vec2 root = cell + vec2(0.0, cellHalf.y * 0.6);
    float dist = boltDistance(fragCoord, root, root + vec2(0.7, 1.6) * cellHeight, grow, seed, jag);
    dist = min(dist, boltDistance(fragCoord, root, root + vec2(-0.55, 1.05) * cellHeight, grow, seed + 23.0, jag * 0.7) + 0.4);

    float core = 1.0 - smoothstep(CORE_WIDTH * 0.5, CORE_WIDTH * 0.5 + 1.0, dist);
    float glow = exp(-dist / GLOW_RADIUS);
    // The glyph itself is charged and flickers with the strikes.
    float flicker = 0.75 + 0.25 * hash(seed + 3.0);
    // A block cursor reads as solid ink, so charge it gently or the cell blows out.
    float charge = hudGlyphGlow(fragCoord, cell, cellHalf, 2.0) * strike * flicker * (typed ? 1.0 : 0.4);

    float alpha = hudSaturate((core * 0.95 + glow * 0.32) * strike + charge * 0.8);
    vec3 color = base.rgb
        + (HUD_FLASH * core * 0.95 + hudAccent() * glow * 0.45) * strike
        + mix(HUD_FLASH, hudAccent(), 0.4) * charge * 0.8;
    fragColor = vec4(min(color, vec3(1.0)), max(base.a, alpha));
}
