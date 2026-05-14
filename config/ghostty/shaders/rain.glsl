const float RAIN_TILT = 0.18;
const float RAIN_ALPHA = 0.34;
const float RAIN_TEXT_DODGE = 0.55;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float rainLayer(vec2 p, float scale, float speed, float density, float width, float dropLength, float seed) {
    vec2 rp = p;
    rp.x += rp.y * RAIN_TILT;
    rp.y += iTime * speed;

    float aspect = iResolution.x / iResolution.y;
    vec2 grid = vec2(scale * aspect, scale * 1.8);
    vec2 cell = floor(rp * grid);
    vec2 local = fract(rp * grid);

    float rnd = hash12(cell + vec2(seed, seed * 2.17));
    float activeDrop = step(1.0 - density, rnd);
    float center = mix(0.18, 0.82, hash12(cell + vec2(seed * 3.41, seed)));
    float line = 1.0 - smoothstep(width, width * 2.8, abs(local.x - center));

    float body = smoothstep(0.0, 0.08, local.y) * (1.0 - smoothstep(dropLength, dropLength + 0.16, local.y));
    float head = 1.0 - smoothstep(0.0, 0.055, abs(local.y - dropLength));

    return activeDrop * line * max(body * 0.72, head);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = fragCoord.xy / iResolution.y;
    vec4 baseColor = texture(iChannel0, uv);

    float rain = 0.0;
    rain += rainLayer(p, 18.0, 0.28, 0.48, 0.030, 0.62, 1.0) * 0.46;
    rain += rainLayer(p, 31.0, 0.42, 0.36, 0.022, 0.52, 7.0) * 0.34;
    rain += rainLayer(p, 46.0, 0.58, 0.26, 0.018, 0.42, 13.0) * 0.24;
    rain = clamp(rain, 0.0, 1.0);

    float textMask = smoothstep(0.18, 0.86, baseColor.a);
    float overlay = rain * RAIN_ALPHA * mix(1.0, RAIN_TEXT_DODGE, textMask);

    vec3 rainColor = mix(iForegroundColor, vec3(0.56, 0.76, 1.0), 0.64);
    vec3 color = baseColor.rgb + rainColor * overlay * (1.0 - baseColor.a * 0.35);
    float alpha = max(baseColor.a, overlay * 0.82);

    fragColor = vec4(color, alpha);
}
