// Input-line lock-on when Ghostty gains focus: corner brackets collapse from a
// tall frame onto the line being typed (from the left edge to just past the
// cursor), snap with the same wobble as the cursor reticle, flash, and fade
// while a faint band lights the line.

const float DURATION = 0.62;
const float LOCK_TIME = 0.20;
const float EDGE_INSET = 6.0;
const float TRAIL_CELLS = 1.5;
const float MIN_WIDTH_CELLS = 10.0;
const float START_ROWS = 3.0;
const float START_SPREAD_CELLS = 1.5;
const float PAD = 3.0;
const float BRACKET_WIDTH = 2.2;
const float WOBBLE_FREQUENCY = 38.0;
const float WOBBLE_DAMPING = 13.0;
const float WOBBLE_AMOUNT = 0.25;
const float BAND_OPACITY = 0.08;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    float elapsed = iTime - iTimeFocus;
    if (iFocus == 0 || iCursorVisible == 0 || elapsed >= DURATION) {
        return;
    }

    float cellHeight = max(iCurrentCursor.w, 1.0);
    float cellWidth = max(iCurrentCursor.z, cellHeight * 0.5);
    float lineY = iCurrentCursor.y - cellHeight * 0.5;
    float left = EDGE_INSET;
    float right = min(iResolution.x - EDGE_INSET, max(iCurrentCursor.x + cellWidth * TRAIL_CELLS, left + cellWidth * MIN_WIDTH_CELLS));
    vec2 center = vec2((left + right) * 0.5, lineY);
    vec2 rest = vec2((right - left) * 0.5, cellHeight * 0.5) + PAD;

    vec2 offset = fragCoord - center;
    if (abs(offset.y) > cellHeight * (START_ROWS + 1.0) || abs(offset.x) > rest.x + cellHeight * (START_SPREAD_CELLS + 1.0)) {
        return;
    }

    float lockTime = elapsed - LOCK_TIME;
    float homing = hudHoming(elapsed / LOCK_TIME);
    float wobble = hudWobble(lockTime, WOBBLE_FREQUENCY, WOBBLE_DAMPING) * WOBBLE_AMOUNT;
    // Collapse mostly vertically onto the row; the wobble squeezes it past the line.
    vec2 frame = vec2(
        rest.x + cellHeight * START_SPREAD_CELLS * (1.0 - homing),
        rest.y + cellHeight * START_ROWS * (1.0 - homing)
    ) - vec2(cellHeight * 0.3, rest.y) * wobble;

    float arm = cellHeight * 0.7;
    float bracket = hudBrackets(offset, frame, arm, BRACKET_WIDTH);
    float bracketAlpha = smoothstep(0.0, 0.05, elapsed) * (1.0 - smoothstep(LOCK_TIME + 0.12, DURATION, elapsed));
    vec3 bracketColor = mix(hudAccent(), HUD_FLASH, exp(-abs(lockTime) * 16.0) * 0.7);

    // Band across the locked line, released at contact.
    float band = 0.0;
    if (lockTime > 0.0) {
        vec2 d = abs(offset) - rest;
        band = (1.0 - smoothstep(0.0, 3.0, max(d.x, d.y))) * exp(-lockTime * 6.0) * BAND_OPACITY;
    }

    float alpha = bracket * bracketAlpha * 0.9 + band;
    vec3 color = base.rgb + bracketColor * bracket * bracketAlpha * 0.9 + hudAccent() * band;
    fragColor = vec4(min(color, vec3(1.0)), max(base.a, hudSaturate(alpha)));
}
