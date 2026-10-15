// Spring-driven cursor smear. The head snaps toward the new cell on a fast
// critically damped spring while the tail follows on a slower one, so the
// shape stretches and collapses into the cursor. Mid-range moves end with a
// small bracket tick snapping onto the cell; long jumps leave the full
// reticle to jump_lockon.glsl.

const float DURATION = 0.24;
// Shorter moves belong to typing_ignite.glsl.
const float MIN_DISTANCE_CELLS = 1.4;
const float LOCKON_DISTANCE_CELLS = 7.0;
const float HEAD_RATE = 30.0;
const float TAIL_RATE = 13.0;
const float TAIL_SCALE = 0.32;
const float BAR_MIN_WIDTH = 0.14;
const float FILL_OPACITY = 0.42;
const float RIM_OPACITY = 0.36;
const float GLOW_OPACITY = 0.24;
const float GLOW_RADIUS = 9.0;
const float TICK_START = 0.08;
const float TICK_SNAP = 0.13;
const float TICK_END = 0.34;
const float TICK_SCALE = 1.9;

// Position of a critically damped spring released from 0 toward 1.
float spring(float t, float rate) {
    float x = rate * t;
    return 1.0 - (1.0 + x) * exp(-x);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    if (iFocus == 0 || iCursorVisible == 0) {
        return;
    }

    float elapsed = iTime - iTimeCursorChange;
    if (elapsed >= max(DURATION, TICK_END)) {
        return;
    }

    float cellHeight = max(iCurrentCursor.w, 1.0);
    vec2 from = hudCellCenter(iPreviousCursor);
    vec2 to = hudCellCenter(iCurrentCursor);
    float distanceCells = length(to - from) / cellHeight;
    if (distanceCells < MIN_DISTANCE_CELLS) {
        return;
    }

    vec3 color = base.rgb;
    float alpha = 0.0;

    if (elapsed < DURATION) {
        vec2 head = mix(from, to, spring(elapsed, HEAD_RATE));
        vec2 tail = mix(from, to, spring(elapsed, TAIL_RATE));
        vec2 axis = head - tail;
        float axisLength = dot(axis, axis);

        // Project onto the tail-to-head axis and sweep a box that tapers toward
        // the tail; clamping keeps box-shaped caps on both ends.
        float along = axisLength > 1e-3 ? hudSaturate(dot(fragCoord - tail, axis) / axisLength) : 1.0;
        vec2 headHalf = max(iCurrentCursor.zw * 0.5, vec2(cellHeight * BAR_MIN_WIDTH, 1.0));
        vec2 halfSize = headHalf * mix(TAIL_SCALE, 1.0, along);
        float dist = hudRoundBox(fragCoord - mix(tail, head, along), halfSize, min(halfSize.x, halfSize.y) * 0.65);

        if (dist < GLOW_RADIUS * 3.0) {
            float fade = 1.0 - smoothstep(0.45, 1.0, elapsed / DURATION);
            float fill = 1.0 - smoothstep(-1.0, 1.0, dist);
            float rim = exp(-dist * dist * 0.35);
            float glow = exp(-max(dist, 0.0) / GLOW_RADIUS);

            // Keep the glyph under a block cursor readable once the head has landed.
            float inCursor = 1.0 - smoothstep(-1.0, 1.0, hudRoundBox(fragCoord - to, iCurrentCursor.zw * 0.5, 0.0));
            fill *= 1.0 - inCursor * 0.85;

            // The accent body brightens toward the cursor-colored head.
            vec3 trail = mix(hudAccent() * 0.8, iCurrentCursorColor.rgb, along * along);
            float a = (fill * FILL_OPACITY + rim * RIM_OPACITY + glow * GLOW_OPACITY) * smoothstep(0.0, 0.4, along) * fade;
            color += trail * a;
            alpha += a;
        }
    }

    // Bracket tick: a small frame snaps onto the landing cell, flashes, fades.
    if (distanceCells < LOCKON_DISTANCE_CELLS && elapsed > TICK_START) {
        vec2 cellHalf = vec2(max(iCurrentCursor.z, cellHeight * 0.5), cellHeight) * 0.5;
        float snap = hudHoming((elapsed - TICK_START) / (TICK_SNAP - TICK_START));
        vec2 frame = cellHalf * mix(TICK_SCALE, 1.0, snap) + 2.0;
        float tick = hudBrackets(fragCoord - to, frame, min(frame.x, frame.y) * 0.4 + 1.5, 1.6);
        float tickAlpha = 1.0 - smoothstep(TICK_SNAP + 0.04, TICK_END, elapsed);
        vec3 tickColor = mix(hudAccent(), HUD_FLASH, exp(-max(elapsed - TICK_SNAP, 0.0) * 25.0) * 0.6);
        color += tickColor * tick * tickAlpha * 0.75;
        alpha += tick * tickAlpha * 0.75;
    }

    fragColor = vec4(min(color, vec3(1.0)), max(base.a, hudSaturate(alpha)));
}
