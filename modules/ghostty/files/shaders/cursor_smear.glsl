// Spring-driven cursor smear. The head snaps toward the new cell on a fast
// critically damped spring while the tail follows on a slower one, so the
// shape stretches and then collapses into the cursor. Light bands flow from
// the tail toward the head while it is stretched.

const float DURATION = 0.24;
// Shorter moves belong to typing_ignite.glsl.
const float MIN_DISTANCE_CELLS = 1.4;
const float HEAD_RATE = 30.0;
const float TAIL_RATE = 13.0;
const float TAIL_SCALE = 0.32;
const float BAR_MIN_WIDTH = 0.14;
const float FILL_OPACITY = 0.46;
const float RIM_OPACITY = 0.38;
const float GLOW_OPACITY = 0.28;
const float GLOW_RADIUS = 9.0;
const float BAND_SPEED = 38.0;

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

// Position of a critically damped spring released from 0 toward 1.
float spring(float t, float rate) {
    float x = rate * t;
    return 1.0 - (1.0 + x) * exp(-x);
}

float sdRoundBox(vec2 p, vec2 halfSize, float radius) {
    vec2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

vec2 cellCenter(vec4 cursor) {
    return cursor.xy + vec2(cursor.z, -cursor.w) * 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    if (iFocus == 0 || iCursorVisible == 0) {
        return;
    }

    float elapsed = iTime - iTimeCursorChange;
    if (elapsed >= DURATION) {
        return;
    }

    float cellHeight = max(iCurrentCursor.w, 1.0);
    vec2 from = cellCenter(iPreviousCursor);
    vec2 to = cellCenter(iCurrentCursor);
    if (length(to - from) < MIN_DISTANCE_CELLS * cellHeight) {
        return;
    }

    vec2 head = mix(from, to, spring(elapsed, HEAD_RATE));
    vec2 tail = mix(from, to, spring(elapsed, TAIL_RATE));
    vec2 axis = head - tail;
    float axisLength = dot(axis, axis);

    // Project onto the tail-to-head axis and sweep a box that tapers toward
    // the tail; clamping keeps box-shaped caps on both ends.
    float along = axisLength > 1e-3 ? saturate(dot(fragCoord - tail, axis) / axisLength) : 1.0;
    vec2 headHalf = max(iCurrentCursor.zw * 0.5, vec2(cellHeight * BAR_MIN_WIDTH, 1.0));
    vec2 halfSize = headHalf * mix(TAIL_SCALE, 1.0, along);
    float radius = min(halfSize.x, halfSize.y) * 0.65;
    float dist = sdRoundBox(fragCoord - mix(tail, head, along), halfSize, radius);
    if (dist > GLOW_RADIUS * 3.0) {
        return;
    }

    float fade = 1.0 - smoothstep(0.45, 1.0, elapsed / DURATION);
    float fill = 1.0 - smoothstep(-1.0, 1.0, dist);
    float rim = exp(-dist * dist * 0.35);
    float glow = exp(-max(dist, 0.0) / GLOW_RADIUS);

    // Keep the glyph under a block cursor readable once the head has landed.
    float inCursor = 1.0 - smoothstep(-1.0, 1.0, sdRoundBox(fragCoord - to, iCurrentCursor.zw * 0.5, 0.0));
    fill *= 1.0 - inCursor * 0.85;

    float trailLength = length(head - tail);
    float bands = 0.6 + 0.4 * sin(along * trailLength / cellHeight * 2.4 - elapsed * BAND_SPEED);
    float tailFade = smoothstep(0.0, 0.4, along);

    vec3 tailColor = mix(iPalette[5], iBackgroundColor, 0.2);
    vec3 color = mix(tailColor, iCurrentCursorColor.rgb, along * along);
    float alpha = (fill * FILL_OPACITY * bands + rim * RIM_OPACITY + glow * GLOW_OPACITY) * tailFade * fade;

    fragColor = vec4(min(base.rgb + color * alpha, vec3(1.0)), max(base.a, saturate(alpha)));
}
