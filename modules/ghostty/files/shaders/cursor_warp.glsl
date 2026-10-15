// Neovide-style stretched cursor trail with a soft glow and landing flash.
// Adapted from glassesneo/dotfiles cursor_warp.glsl (MIT).

const float DURATION = 0.16;
const float WARP_MIN_DISTANCE = 14.0;
const float SOFTNESS = 1.25;
const float GLOW = 6.0;
const float TRAIL_OPACITY = 0.62;
const float GLOW_OPACITY = 0.22;
const float HEAD_OPACITY = 0.30;
// Bar cursors are only a few pixels wide, so give the trail a minimum
// thickness relative to the cell height to keep it readable as a comet.
const float MIN_THICKNESS = 0.18;

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

float easeOutCubic(float x) {
    float t = 1.0 - saturate(x);
    return 1.0 - t * t * t;
}

// Distance to the segment in a space scaled by the cursor half-size, so the
// trail sweeps the cursor shape instead of a circle.
float sweptDistance(vec2 p, vec2 a, vec2 b, vec2 halfSize, out float along) {
    vec2 sp = p / halfSize;
    vec2 sa = a / halfSize;
    vec2 sb = b / halfSize;
    vec2 ab = sb - sa;
    along = saturate(dot(sp - sa, ab) / max(dot(ab, ab), 1e-4));
    return length(sp - mix(sa, sb, along));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    fragColor = base;

    if (iFocus == 0 || iCursorVisible == 0) {
        return;
    }

    float elapsed = iTime - iTimeCursorChange;
    if (elapsed >= DURATION) {
        return;
    }

    vec2 prevCenter = iPreviousCursor.xy + vec2(iPreviousCursor.z, -iPreviousCursor.w) * 0.5;
    vec2 curCenter = iCurrentCursor.xy + vec2(iCurrentCursor.z, -iCurrentCursor.w) * 0.5;
    if (length(curCenter - prevCenter) < WARP_MIN_DISTANCE) {
        return;
    }

    float life = saturate(elapsed / DURATION);
    float fade = (1.0 - life) * (1.0 - life);
    vec2 trailHead = mix(prevCenter, curCenter, easeOutCubic(life));

    vec2 halfSize = max(iCurrentCursor.zw * 0.5, vec2(iCurrentCursor.w * MIN_THICKNESS, 1.0));
    float minHalf = min(halfSize.x, halfSize.y);

    float along = 0.0;
    float dist = sweptDistance(fragCoord, prevCenter, trailHead, halfSize, along);
    // Thin out toward the tail.
    float taper = mix(0.45, 1.0, along);
    float soft = SOFTNESS / minHalf;
    float body = 1.0 - smoothstep(taper - soft, taper + soft, dist);
    float glow = 1.0 - smoothstep(taper, taper + GLOW / minHalf, dist);

    float headDist = length((fragCoord - curCenter) / halfSize);
    float head = 1.0 - smoothstep(0.4, 1.0 + GLOW / minHalf, headDist);

    // Fade from the palette magenta at the tail into the cursor color.
    vec3 trailColor = mix(iPalette[5], iCurrentCursorColor.rgb, along);
    float alpha = body * TRAIL_OPACITY * fade + glow * GLOW_OPACITY * fade;
    float headAlpha = head * HEAD_OPACITY * fade;
    vec3 color = base.rgb + trailColor * alpha + iCurrentCursorColor.rgb * headAlpha;

    fragColor = vec4(min(color, vec3(1.0)), max(base.a, saturate(alpha + headAlpha)));
}
