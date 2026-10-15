// Ignition for the glyph that was just typed. The cell the cursor left behind
// is the new character: its strokes flash white, cool into the HUD accent,
// and a thin scan line spreads from its baseline.

const float DURATION = 0.42;
// Wide glyphs advance about one cell height; anything longer is a paste or jump.
const float MAX_ADVANCE_CELLS = 1.2;
const float GLOW_TAP_RADIUS = 2.0;
const float GLOW_PAD = 7.0;
const float GLOW_OPACITY = 0.85;
const float HEAT_TIME = 0.24;
const float SCAN_SPREAD = 1.8;
const float SCAN_OPACITY = 0.5;

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
    if (abs(local.x) > cellHalf.x * (1.0 + SCAN_SPREAD) + GLOW_PAD || abs(local.y) > cellHalf.y + GLOW_PAD) {
        return;
    }

    float life = hudSaturate(elapsed / DURATION);
    float fade = (1.0 - life) * (1.0 - life);
    vec3 heat = mix(HUD_FLASH, hudAccent(), smoothstep(0.0, HEAT_TIME, elapsed));

    float alpha = hudGlyphGlow(fragCoord, cell, cellHalf, GLOW_TAP_RADIUS) * GLOW_OPACITY * fade;

    // Scan line spreading sideways from the cell's baseline.
    float spread = cellHalf.x * (1.0 + SCAN_SPREAD * sqrt(life));
    float baseline = local.y + cellHalf.y - 1.0;
    float scan = exp(-baseline * baseline * 0.6) * (1.0 - smoothstep(spread * 0.4, spread, abs(local.x)));
    alpha += scan * SCAN_OPACITY * fade;

    fragColor = vec4(min(base.rgb + heat * alpha, vec3(1.0)), max(base.a, hudSaturate(alpha)));
}
