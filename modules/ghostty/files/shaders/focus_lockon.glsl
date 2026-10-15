// Window lock-on when Ghostty gains focus: corner brackets home in from beyond
// the window edges, snap onto the frame with the same wobble as the cursor
// reticle, flash, and fade while a faint glow washes along the edges.

const float DURATION = 0.62;
const float LOCK_TIME = 0.20;
const float INSET = 14.0;
const float START_OVERSHOOT = 1.10;
const float ARM_FRACTION = 0.07;
const float BRACKET_WIDTH = 2.6;
const float WOBBLE_FREQUENCY = 34.0;
const float WOBBLE_DAMPING = 12.0;
const float WOBBLE_AMOUNT = 0.012;
const float EDGE_GLOW = 0.10;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    float elapsed = iTime - iTimeFocus;
    if (iFocus == 0 || elapsed >= DURATION) {
        return;
    }

    vec2 center = iResolution.xy * 0.5;
    vec2 offset = fragCoord - center;
    vec2 rest = center - INSET;
    float lockTime = elapsed - LOCK_TIME;
    float homing = hudHoming(elapsed / LOCK_TIME);
    float scale = mix(START_OVERSHOOT, 1.0, homing) - hudWobble(lockTime, WOBBLE_FREQUENCY, WOBBLE_DAMPING) * WOBBLE_AMOUNT;
    vec2 frame = rest * scale;

    // Only the corners can be lit, so skip the middle of the window cheaply.
    float arm = min(rest.x, rest.y) * 2.0 * ARM_FRACTION;
    vec2 q = abs(offset);
    float edge = min(rest.x - q.x, rest.y - q.y);
    if (q.x < frame.x - arm - 4.0 && q.y < frame.y - arm - 4.0 && edge > INSET * 4.0) {
        return;
    }

    float bracket = hudBrackets(offset, frame, arm, BRACKET_WIDTH);
    float bracketAlpha = smoothstep(0.0, 0.05, elapsed) * (1.0 - smoothstep(LOCK_TIME + 0.12, DURATION, elapsed));
    vec3 bracketColor = mix(hudAccent(), HUD_FLASH, exp(-abs(lockTime) * 16.0) * 0.7);

    // Edge glow released at lock time, strongest along the border.
    float glow = 0.0;
    if (lockTime > 0.0) {
        float border = min(center.x - q.x, center.y - q.y);
        glow = exp(-max(border, 0.0) / (INSET * 2.0)) * exp(-lockTime * 7.0) * EDGE_GLOW;
    }

    float alpha = bracket * bracketAlpha * 0.9 + glow;
    vec3 color = base.rgb + bracketColor * bracket * bracketAlpha * 0.9 + hudAccent() * glow;
    fragColor = vec4(min(color, vec3(1.0)), max(base.a, hudSaturate(alpha)));
}
