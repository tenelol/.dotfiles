// Ink ripple that distorts the screen around the cursor after a large jump.
// Typing-scale motion is ignored. Adapted from glassesneo/dotfiles
// cursor_ink_ripple.glsl (MIT).

// Start as cursor_warp.glsl lands so the trail and ripple read as one motion.
const float START_DELAY = 0.14;
const float DURATION = 0.85;
const float MIN_RIPPLE_DISTANCE = 540.0;
const float RADIUS_SCALE = 0.10;
const float RADIUS_MIN = 48.0;
const float RADIUS_MAX = 220.0;
const float RING_WIDTH = 12.0;
const float OUTER_RING_SCALE = 1.48;
const float INNER_RING_SCALE = 0.46;
const float DISTORTION_STRENGTH = 30.0;
const float RIPPLE_FREQUENCY = 0.185;
const float RIPPLE_SPEED = 18.0;
const float INK_STRENGTH = 0.55;

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

float easeOutCubic(float x) {
    float t = 1.0 - saturate(x);
    return 1.0 - t * t * t;
}

float ringBand(float dist, float radius, float width) {
    return smoothstep(width, 0.0, abs(dist - radius));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    fragColor = base;

    if (iFocus == 0 || iCursorVisible == 0) {
        return;
    }

    float activeElapsed = iTime - iTimeCursorChange - START_DELAY;
    if (activeElapsed < 0.0 || activeElapsed >= DURATION) {
        return;
    }

    vec2 prevCenter = iPreviousCursor.xy + vec2(iPreviousCursor.z, -iPreviousCursor.w) * 0.5;
    vec2 curCenter = iCurrentCursor.xy + vec2(iCurrentCursor.z, -iCurrentCursor.w) * 0.5;
    float moveDistance = length(curCenter - prevCenter);
    if (moveDistance < MIN_RIPPLE_DISTANCE) {
        return;
    }

    float life = saturate(activeElapsed / DURATION);
    float fade = (1.0 - life) * (1.0 - life);
    float radius = clamp(moveDistance * RADIUS_SCALE, RADIUS_MIN, RADIUS_MAX) * easeOutCubic(life);

    vec2 fromCenter = fragCoord - curCenter;
    float dist = length(fromCenter);
    // Skip pixels the outermost ring cannot reach.
    if (dist > radius * OUTER_RING_SCALE + RING_WIDTH * 12.0) {
        return;
    }
    vec2 normal = dist > 1e-4 ? fromCenter / dist : vec2(1.0, 0.0);

    float primaryRing = ringBand(dist, radius, RING_WIDTH);
    float outerRing = ringBand(dist, radius * OUTER_RING_SCALE, RING_WIDTH * 1.22) * 0.72;
    float innerRing = ringBand(dist, radius * INNER_RING_SCALE, RING_WIDTH * 1.08) * 0.55;
    float rippleField = primaryRing + outerRing + innerRing;

    float waveEnvelope =
        exp(-abs(dist - radius) * 0.060) +
        exp(-abs(dist - radius * OUTER_RING_SCALE) * 0.050) * 0.65 +
        exp(-abs(dist - radius * INNER_RING_SCALE) * 0.070) * 0.45;
    float wave = sin(dist * RIPPLE_FREQUENCY - life * RIPPLE_SPEED);
    float displacement = wave * waveEnvelope * DISTORTION_STRENGTH * fade;

    vec2 distortedUv = clamp(uv + normal * (displacement / iResolution.xy), vec2(0.0), vec2(1.0));
    vec4 distorted = texture(iChannel0, distortedUv);

    vec3 inkColor = mix(iBackgroundColor, vec3(0.0), 0.60);
    vec3 ringColor = mix(iBackgroundColor, iPalette[4], 0.55);

    float distortionAlpha = saturate(waveEnvelope * 0.95 * fade);
    float inkMask = saturate((waveEnvelope * 0.55 + rippleField * 0.42) * fade) * INK_STRENGTH;
    vec3 color = mix(base.rgb, distorted.rgb, distortionAlpha);
    color = mix(color, inkColor, inkMask);
    color = mix(color, ringColor, outerRing * 0.18 * fade);
    color = mix(color, ringColor, innerRing * 0.14 * fade);

    fragColor = vec4(clamp(color, 0.0, 1.0), max(base.a, mix(base.a, distorted.a, distortionAlpha)));
}
