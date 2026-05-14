const float RAIN_SLANT = -0.18;
const float RAIN_OPACITY = 0.18;
const vec3 RAIN_TINT = vec3(0.62, 0.78, 1.0);

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float rainLayer(
    vec2 uv,
    float columns,
    float rows,
    float speed,
    float density,
    float width,
    float streakLength
) {
    vec2 p = uv;
    p.x += p.y * RAIN_SLANT;
    p *= vec2(columns, rows);

    vec2 cell = floor(p);
    vec2 local = fract(p);

    float seed = hash12(cell);
    float active = step(density, seed);
    float dropX = hash12(cell + vec2(17.31, 29.17));
    float dropSpeed = speed * mix(0.72, 1.28, hash12(cell + vec2(41.0, 7.0)));
    float y = fract(local.y + iTime * dropSpeed + seed);

    float line = smoothstep(width, 0.0, abs(local.x - dropX));
    float tail = smoothstep(streakLength, 0.0, y);
    float head = smoothstep(width * 2.6, 0.0, length(vec2((local.x - dropX) * 2.5, y * 0.32)));

    return active * max(line * tail, head * 0.55);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 baseColor = texture(iChannel0, uv);

    float slowRain = rainLayer(uv, 42.0, 18.0, 0.34, 0.58, 0.045, 0.66);
    float fineRain = rainLayer(uv + vec2(0.19, 0.0), 76.0, 30.0, 0.58, 0.76, 0.034, 0.48);
    float rain = clamp(slowRain * 0.72 + fineRain * 0.42, 0.0, 1.0);

    float bgDistance = length(baseColor.rgb - iBackgroundColor);
    float fgDistance = length(baseColor.rgb - iForegroundColor);
    float bgLuma = luminance(iBackgroundColor);
    float darkBackground = 1.0 - smoothstep(0.35, 0.58, bgLuma);
    float lightBackground = smoothstep(0.48, 0.72, bgLuma);
    float brightText = smoothstep(0.54, 0.86, luminance(baseColor.rgb)) * darkBackground;
    float darkText = (1.0 - smoothstep(0.16, 0.36, luminance(baseColor.rgb))) * lightBackground;
    float foregroundLike = 1.0 - smoothstep(0.08, 0.34, fgDistance);
    float textGuard = max(max(brightText, darkText), foregroundLike);
    float backgroundLike = 1.0 - smoothstep(0.08, 0.38, bgDistance);
    float backgroundMask = mix(0.42, 1.0, backgroundLike) * (1.0 - textGuard * 0.82);

    vec3 rainColor = mix(RAIN_TINT, iForegroundColor, 0.22);
    float alpha = rain * RAIN_OPACITY * backgroundMask;

    vec3 color = mix(baseColor.rgb, rainColor, alpha);
    color += rainColor * alpha * 0.18;

    fragColor = vec4(color, baseColor.a);
}
