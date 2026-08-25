const float FOCUS_DURATION = 0.48;
const float LENS_RADIUS = 0.145;
const float EDGE_SOFTNESS = 0.018;
const float DISTORTION_STRENGTH = 0.020;
const float CHROMA_SHIFT = 0.0022;
const float EDGE_HIGHLIGHT = 0.16;

const float PI = 3.14159265359;

float easeOutCubic(float x) {
    x = clamp(x, 0.0, 1.0);
    return 1.0 - pow(1.0 - x, 3.0);
}

vec2 normalizeToScreen(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

vec2 normalizedOffsetToUv(vec2 value) {
    return vec2(
        value.x * iResolution.y / (2.0 * iResolution.x),
        value.y * 0.5
    );
}

vec2 clampUv(vec2 uv) {
    vec2 texel = 1.0 / iResolution.xy;
    return clamp(uv, texel, 1.0 - texel);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 baseColor = texture(iChannel0, uv);

    if (iFocus == 0) {
        fragColor = baseColor;
        return;
    }

    float progress = (iTime - iTimeFocus) / FOCUS_DURATION;
    if (progress >= 1.0) {
        fragColor = baseColor;
        return;
    }

    progress = clamp(progress, 0.0, 1.0);
    float temporal = sin(progress * PI);

    vec2 p = normalizeToScreen(fragCoord.xy, 1.0);
    vec4 cursor = vec4(
        normalizeToScreen(iCurrentCursor.xy, 1.0),
        normalizeToScreen(iCurrentCursor.zw, 0.0)
    );
    vec2 center = cursor.xy + vec2(cursor.z * 0.5, -cursor.w * 0.5);

    float radius = LENS_RADIUS * mix(0.82, 1.0, easeOutCubic(progress));
    vec2 delta = p - center;
    float dist = length(delta);
    float lensMask = 1.0 - smoothstep(radius, radius + EDGE_SOFTNESS, dist);

    if (lensMask <= 0.0) {
        fragColor = baseColor;
        return;
    }

    vec2 dir = dist > 0.0001 ? delta / dist : vec2(0.0, 1.0);
    float unitDist = clamp(dist / radius, 0.0, 1.0);
    float dome = sqrt(max(0.0, 1.0 - unitDist * unitDist));
    float edge = smoothstep(0.68, 1.0, unitDist) * lensMask;

    float distortion = DISTORTION_STRENGTH * temporal * dome * lensMask;
    vec2 sampleUv = clampUv(uv - normalizedOffsetToUv(dir * distortion));

    vec2 chroma = normalizedOffsetToUv(dir * CHROMA_SHIFT * temporal * edge);
    vec4 glassColor = texture(iChannel0, sampleUv);
    glassColor.r = texture(iChannel0, clampUv(sampleUv - chroma)).r;
    glassColor.b = texture(iChannel0, clampUv(sampleUv + chroma)).b;

    vec3 rimColor = mix(vec3(0.92, 0.96, 1.0), iForegroundColor, 0.22);
    vec3 color = mix(baseColor.rgb, glassColor.rgb, lensMask * temporal);
    color += rimColor * edge * temporal * EDGE_HIGHLIGHT;
    color += iBackgroundColor * lensMask * temporal * 0.035;

    fragColor = vec4(color, mix(baseColor.a, glassColor.a, lensMask * temporal));
}
