// Neon ignition for the glyph that was just typed. The cell the cursor left
// behind is the new character: its strokes flash white-hot, cool into a
// palette accent, and a thin underline spark spreads from it.

const float DURATION = 0.42;
// Wide glyphs advance about one cell height; anything longer is a paste or jump.
const float MAX_ADVANCE_CELLS = 1.2;
const float GLOW_TAP_RADIUS = 2.0;
const float GLOW_PAD = 7.0;
const float GLOW_OPACITY = 0.85;
const float HEAT_TIME = 0.28;
const float UNDERLINE_SPREAD = 1.8;
const float UNDERLINE_OPACITY = 0.55;
const int EMBER_COUNT = 3;

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

float hash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float insideBox(vec2 p, vec2 center, vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    return step(max(d.x, d.y), 0.0);
}

// Glyph coverage of the typed cell only, so neighbours never light up.
float glyphMask(vec2 p, vec2 center, vec2 halfSize) {
    float ink = luma(texture(iChannel0, p / iResolution.xy).rgb) - luma(iBackgroundColor);
    return smoothstep(0.12, 0.45, ink) * insideBox(p, center, halfSize);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    if (iFocus == 0 || iCursorVisible == 0 || iCurrentCursorStyle != CURSORSTYLE_BAR) {
        return;
    }

    float elapsed = iTime - iTimeCursorChange;
    if (elapsed >= DURATION) {
        return;
    }

    float cellHeight = max(iCurrentCursor.w, 1.0);
    vec2 advance = iCurrentCursor.xy - iPreviousCursor.xy;
    // Only forward moves on the same row are typing; backspace stays quiet.
    if (advance.x < 1.0 || abs(advance.y) > 0.5 || advance.x > MAX_ADVANCE_CELLS * cellHeight) {
        return;
    }

    vec2 cellHalf = vec2(advance.x, cellHeight) * 0.5;
    vec2 cell = vec2(iPreviousCursor.x, iPreviousCursor.y - cellHeight) + cellHalf;
    vec2 local = fragCoord - cell;
    if (abs(local.x) > cellHalf.x * (1.0 + UNDERLINE_SPREAD) + GLOW_PAD || abs(local.y) > cellHalf.y + cellHeight) {
        return;
    }

    float life = saturate(elapsed / DURATION);
    float fade = (1.0 - life) * (1.0 - life);
    float seed = floor(iTimeCursorChange * 1000.0);
    vec3 accent = iPalette[1 + int(hash(seed) * 6.0)];
    vec3 heat = mix(vec3(1.0), accent, smoothstep(0.0, HEAT_TIME, elapsed));

    // Cheap bloom: the glyph mask sampled on a tight and a wide ring, with the
    // wide ring offset by half a step so the halo stays round.
    float glow = glyphMask(fragCoord, cell, cellHalf) * 0.6;
    for (int i = 0; i < 8; ++i) {
        float angle = float(i) * 0.78539816;
        vec2 dir = vec2(cos(angle), sin(angle));
        vec2 wideDir = vec2(cos(angle + 0.3927), sin(angle + 0.3927));
        glow += glyphMask(fragCoord + dir * GLOW_TAP_RADIUS, cell, cellHalf) * 0.12;
        glow += glyphMask(fragCoord + wideDir * GLOW_TAP_RADIUS * 2.5, cell, cellHalf) * 0.06;
    }
    float alpha = saturate(glow) * GLOW_OPACITY * fade;

    // Underline spark spreading sideways from the cell's baseline.
    float spread = cellHalf.x * (1.0 + UNDERLINE_SPREAD * sqrt(life));
    float baseline = local.y + cellHalf.y - 1.0;
    float underline = exp(-baseline * baseline * 0.6) * (1.0 - smoothstep(spread * 0.4, spread, abs(local.x)));
    alpha += underline * UNDERLINE_OPACITY * fade;

    // A few embers drifting up off the top of the glyph.
    for (int i = 0; i < EMBER_COUNT; ++i) {
        float fi = float(i);
        vec2 ember = vec2(
            cell.x + (hash(seed + fi * 3.1) - 0.5) * cellHalf.x * 2.0 + sin(life * 9.0 + fi * 2.0) * 2.5,
            cell.y + cellHalf.y + life * cellHeight * mix(0.6, 1.3, hash(seed + fi * 7.3))
        );
        float emberDist = length(fragCoord - ember);
        alpha += smoothstep(2.4, 0.6, emberDist) * fade * 0.7;
    }

    fragColor = vec4(min(base.rgb + heat * alpha, vec3(1.0)), max(base.a, saturate(alpha)));
}
