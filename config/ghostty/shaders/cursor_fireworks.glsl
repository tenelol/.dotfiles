const int PARTICLE_COUNT = 30;

const float DURATION = 0.72;
const float BURST_RADIUS = 0.125;
const float GRAVITY = 0.055;
const float SPARK_RADIUS = 0.0046;
const float TRAIL_WIDTH = 0.0027;
const float BLOOM_RADIUS = 0.017;
const float PI = 3.14159265359;

float saturate(float value) {
    return clamp(value, 0.0, 1.0);
}

float easeOutCubic(float value) {
    value = saturate(value);
    return 1.0 - pow(1.0 - value, 3.0);
}

vec3 sRGBToLinear(vec3 color) {
    return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), color));
}

vec2 normalizeToScreen(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

vec2 cursorCenter(vec4 cursor) {
    vec4 normalizedCursor = vec4(
        normalizeToScreen(cursor.xy, 1.0),
        normalizeToScreen(cursor.zw, 0.0)
    );

    return normalizedCursor.xy + vec2(normalizedCursor.z * 0.5, -normalizedCursor.w * 0.5);
}

float hash11(float value) {
    value = fract(value * 0.1031);
    value *= value + 33.33;
    value *= value + value;
    return fract(value);
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.000001), 0.0, 1.0);
    return length(pa - ba * h);
}

vec3 fireworkColor(float value) {
    vec3 cyan = sRGBToLinear(vec3(0.49, 0.81, 1.00));
    vec3 magenta = sRGBToLinear(vec3(0.91, 0.60, 1.00));
    vec3 yellow = sRGBToLinear(vec3(1.00, 0.87, 0.36));
    vec3 green = sRGBToLinear(vec3(0.62, 0.88, 0.47));
    vec3 white = sRGBToLinear(vec3(0.96, 0.98, 1.00));

    float band = value * 4.0;
    if (band < 1.0) {
        return mix(cyan, magenta, band);
    }
    if (band < 2.0) {
        return mix(magenta, yellow, band - 1.0);
    }
    if (band < 3.0) {
        return mix(yellow, green, band - 2.0);
    }
    return mix(green, white, band - 3.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 baseColor = texture(iChannel0, uv);

    if (iFocus == 0 || iTimeCursorChange <= 0.0) {
        fragColor = baseColor;
        return;
    }

    float age = iTime - iTimeCursorChange;
    if (age < 0.0 || age >= DURATION) {
        fragColor = baseColor;
        return;
    }

    vec2 p = normalizeToScreen(fragCoord.xy, 1.0);
    vec2 center = cursorCenter(iCurrentCursor);

    float progress = saturate(age / DURATION);
    float expansion = easeOutCubic(progress);
    float fade = pow(1.0 - progress, 1.35);
    float antiAlias = normalizeToScreen(vec2(1.4, 1.4), 0.0).x;
    float burstSeed = iTimeCursorChange * 17.0 + dot(center, vec2(19.19, 43.17));

    float flash = 1.0 - smoothstep(0.0, 0.034, length(p - center));
    vec3 additiveColor = sRGBToLinear(iCurrentCursorColor.rgb) * flash * fade * 0.38;
    float fireworkAlpha = flash * fade * 0.34;

    for (int i = 0; i < PARTICLE_COUNT; i++) {
        float index = float(i);
        float angle = hash11(burstSeed + index * 2.37) * PI * 2.0;
        float speed = mix(0.48, 1.08, hash11(burstSeed + index * 5.91));
        float size = mix(0.72, 1.35, hash11(burstSeed + index * 9.13));
        float colorPick = hash11(burstSeed + index * 12.71);
        float drift = mix(-0.34, 0.34, hash11(burstSeed + index * 15.83)) * progress;

        vec2 direction = vec2(cos(angle + drift), sin(angle + drift));
        float travel = BURST_RADIUS * speed * expansion;
        vec2 gravity = vec2(0.0, -GRAVITY * progress * progress * speed);
        vec2 head = center + direction * travel + gravity;
        vec2 tail = center + direction * max(0.0, travel - BURST_RADIUS * 0.16) + gravity * 0.82;

        float sparkRadius = mix(SPARK_RADIUS, SPARK_RADIUS * 0.42, progress) * size;
        float spark = 1.0 - smoothstep(sparkRadius, sparkRadius + antiAlias, length(p - head));
        float trail = 1.0 - smoothstep(TRAIL_WIDTH, TRAIL_WIDTH + antiAlias, sdSegment(p, tail, head));
        float bloom = 1.0 - smoothstep(BLOOM_RADIUS, BLOOM_RADIUS + antiAlias * 4.0, length(p - head));
        float twinkle = 0.72 + 0.28 * sin((1.0 - progress) * 18.0 + index * 1.87);
        float particleAlpha = fade * twinkle * (spark + trail * 0.58 + bloom * 0.16);

        vec3 particleColor = fireworkColor(colorPick);
        additiveColor += particleColor * particleAlpha;
        fireworkAlpha = max(fireworkAlpha, particleAlpha * 0.82);
    }

    vec3 color = baseColor.rgb + additiveColor;
    fragColor = vec4(color, max(baseColor.a, saturate(fireworkAlpha)));
}
