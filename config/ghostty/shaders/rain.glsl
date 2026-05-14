const float RAIN_SLANT = 0.105;
const float RAIN_ALPHA = 0.24;
const float RAIN_TEXT_DODGE = 0.42;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float drizzleLayer(vec2 p, float columns, float rows, float speed, float density, float width, float dropLength, float seed) {
    vec2 rp = p;
    rp.y -= iTime * speed;
    rp.x -= rp.y * RAIN_SLANT;

    vec2 grid = vec2(columns, rows);
    vec2 cell = floor(rp * grid + vec2(seed, seed * 1.37));
    vec2 local = fract(rp * grid + vec2(seed, seed * 1.37));

    float rnd = hash12(cell + vec2(seed * 2.11, seed * 5.03));
    float activeDrop = step(1.0 - density, rnd);
    float centerX = mix(0.22, 0.78, hash12(cell + vec2(seed * 7.31, seed * 0.43)));
    float wobble = (hash12(cell + vec2(seed * 9.17, seed * 4.61)) - 0.5) * 0.035;

    float lineMask = 1.0 - smoothstep(width, width * 2.6, abs(local.x - centerX - wobble));
    float topFade = smoothstep(0.0, 0.12, local.y);
    float bottomFade = 1.0 - smoothstep(dropLength - 0.10, dropLength, local.y);
    float bodyMask = topFade * bottomFade * step(local.y, dropLength);
    float headGlow = 1.0 - smoothstep(0.0, 0.075, abs(local.y - dropLength * 0.86));
    float brightness = mix(0.55, 1.0, clamp(local.y / dropLength, 0.0, 1.0));

    return activeDrop * lineMask * max(bodyMask * brightness, headGlow * 0.28);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    vec4 baseColor = texture(iChannel0, uv);

    float rain = 0.0;
    rain += drizzleLayer(p, 42.0, 72.0, 0.11, 0.28, 0.020, 0.34, 1.0) * 0.42;
    rain += drizzleLayer(p, 58.0, 96.0, 0.16, 0.22, 0.016, 0.29, 7.0) * 0.34;
    rain += drizzleLayer(p, 76.0, 128.0, 0.21, 0.16, 0.013, 0.24, 13.0) * 0.24;
    rain = clamp(rain, 0.0, 1.0);

    float textMask = smoothstep(0.18, 0.86, baseColor.a);
    float overlay = rain * RAIN_ALPHA * mix(1.0, RAIN_TEXT_DODGE, textMask);

    vec3 rainColor = mix(iForegroundColor, vec3(0.56, 0.76, 1.0), 0.64);
    vec3 color = baseColor.rgb + rainColor * overlay * (1.0 - baseColor.a * 0.35);
    float alpha = max(baseColor.a, overlay * 0.82);

    fragColor = vec4(color, alpha);
}
