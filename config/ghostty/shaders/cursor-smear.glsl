// Cursor motion shader for Ghostty.
// Small one-cell moves get a soft glide. Every move gets stars. Large jumps get
// a circular warp that settles back into place.

const int STAR_COUNT = 10;
const float INPUT_SECONDS = 0.18;
const float STAR_SECONDS = 0.52;
const float WARP_SECONDS = 0.46;
const float WARP_PIXELS = 14.0;
const float TAU = 6.28318530718;

float saturate(float value) {
    return clamp(value, 0.0, 1.0);
}

float hash12(vec2 value) {
    vec3 p = fract(vec3(value.xyx) * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

vec2 rotate(vec2 value, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return vec2(c * value.x - s * value.y, s * value.x + c * value.y);
}

vec2 cursorSize(vec4 cursor) {
    return max(abs(cursor.zw), vec2(1.0));
}

vec2 cursorCenter(vec4 cursor) {
    vec2 size = cursorSize(cursor);
    return cursor.xy + vec2(size.x * 0.5, -size.y * 0.5);
}

float segmentT(vec2 point, vec2 start, vec2 end) {
    vec2 segment = end - start;
    return clamp(dot(point - start, segment) / max(dot(segment, segment), 1.0), 0.0, 1.0);
}

float segmentDistance(vec2 point, vec2 start, vec2 end) {
    float t = segmentT(point, start, end);
    return length(point - mix(start, end, t));
}

vec2 safeNormalize(vec2 value) {
    return value / max(length(value), 0.001);
}

float starShape(vec2 point, float size, float angle) {
    vec2 q = rotate(point, angle);
    float core = exp(-dot(q, q) / max(size * size, 0.001));
    float rayX = saturate(1.0 - abs(q.y) / (size * 0.26)) *
        saturate(1.0 - abs(q.x) / (size * 7.5));
    float rayY = saturate(1.0 - abs(q.x) / (size * 0.26)) *
        saturate(1.0 - abs(q.y) / (size * 7.5));
    return core + (rayX + rayY) * 0.72;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 resolution = iResolution.xy;
    vec2 uv = fragCoord / resolution;

    vec2 current = cursorCenter(iCurrentCursor);
    vec2 previous = cursorCenter(iPreviousCursor);
    vec2 size = cursorSize(iCurrentCursor);
    vec2 delta = current - previous;
    float travel = length(delta);

    float age = max(iTime - iTimeCursorChange, 0.0);
    float focus = clamp(float(iFocus), 0.0, 1.0);

    float cell = max(max(size.x, size.y), 1.0);
    float horizontalStep = 1.0 - smoothstep(cell * 0.22, cell * 0.88, abs(travel - size.x));
    float sameRow = 1.0 - smoothstep(size.y * 0.22, size.y * 0.84, abs(delta.y));
    float shortMove = 1.0 - smoothstep(cell * 1.55, cell * 2.45, travel);
    float inputMove = horizontalStep * sameRow * shortMove * focus;

    float anyMove = smoothstep(cell * 0.35, cell * 1.15, travel) * focus;
    float bigJump = smoothstep(cell * 6.0, cell * 12.0, travel) * anyMove;

    float along = segmentT(fragCoord, previous, current);
    float trailDist = segmentDistance(fragCoord, previous, current);
    vec2 direction = safeNormalize(delta + vec2(0.001, 0.0));

    vec2 fromCursor = fragCoord - current;
    float cursorDistance = length(fromCursor);

    float warpLife = 1.0 - smoothstep(0.0, WARP_SECONDS, age);
    float settle = smoothstep(0.0, 0.18, age) * (1.0 - smoothstep(0.20, WARP_SECONDS, age));
    float radius = mix(cell * 1.8, cell * 9.0, smoothstep(0.0, WARP_SECONDS, age));
    float circularLens = exp(-(cursorDistance * cursorDistance) / max(radius * radius, 1.0));
    float roundRing = exp(-abs(cursorDistance - radius) / max(cell * 1.25, 1.0));
    float settleWave = sin(cursorDistance * 0.18 - age * 34.0) * roundRing;
    vec2 warp = safeNormalize(fromCursor) *
        (circularLens * warpLife * 0.92 + settleWave * settle * 0.58) *
        WARP_PIXELS * bigJump;

    vec2 sampleUv = clamp(uv - warp / resolution, vec2(0.0), vec2(1.0));
    vec2 chroma = safeNormalize(fromCursor + direction) * bigJump * warpLife * 1.6 / resolution;

    vec4 color;
    color.r = texture(iChannel0, clamp(sampleUv + chroma, vec2(0.0), vec2(1.0))).r;
    color.g = texture(iChannel0, sampleUv).g;
    color.b = texture(iChannel0, clamp(sampleUv - chroma, vec2(0.0), vec2(1.0))).b;
    color.a = texture(iChannel0, sampleUv).a;

    vec3 cursorColor = max(iCurrentCursorColor.rgb, vec3(0.18));
    vec3 accent = mix(cursorColor, vec3(0.20, 0.72, 1.0), 0.28);

    float inputLife = 1.0 - smoothstep(0.0, INPUT_SECONDS, age);
    float inputEase = smoothstep(0.0, 1.0, saturate(age / INPUT_SECONDS));
    vec2 easedCursor = mix(previous, current, inputEase);
    float glideTrail = (1.0 - smoothstep(cell * 0.18, cell * 1.15, trailDist)) *
        smoothstep(0.0, 0.12, along) * (1.0 - smoothstep(0.88, 1.0, along));
    float glidePulse = exp(-dot((fragCoord - easedCursor) / (size * 1.25), (fragCoord - easedCursor) / (size * 1.25)));
    color.rgb += accent * inputMove * inputLife * (glideTrail * 0.07 + glidePulse * 0.10);

    float starLife = 1.0 - smoothstep(0.04, STAR_SECONDS, age);
    float starPower = anyMove * starLife;
    float stars = 0.0;

    for (int i = 0; i < STAR_COUNT; i++) {
        float slot = float(i);
        float seed = hash12(current * 0.017 + previous * 0.011 + vec2(slot, slot * 7.1));
        float angle = TAU * hash12(current * 0.013 + vec2(slot * 2.3, slot + 4.0));
        float distance = mix(cell * 0.82, cell * 4.7, hash12(previous * 0.019 + vec2(slot * 5.7, slot)));
        vec2 starPosition = current + vec2(cos(angle), sin(angle)) * distance;
        float delay = seed * 0.12;
        float localLife = saturate(1.0 - smoothstep(delay, STAR_SECONDS, age));
        float pop = sin(saturate((age - delay) / max(STAR_SECONDS - delay, 0.01)) * 3.14159265);
        float sizePx = mix(1.4, 3.4, seed) * (0.72 + pop * 0.55);
        float twinkle = 0.72 + 0.28 * sin(age * 58.0 + seed * TAU);
        stars += starShape(fragCoord - starPosition, sizePx, angle + age * 2.2) *
            localLife * pop * twinkle;
    }

    color.rgb += mix(vec3(1.0, 0.86, 0.44), accent, 0.38) * stars * starPower * 0.52;
    color.rgb += accent * (circularLens * 0.10 + abs(settleWave) * 0.12) * bigJump * warpLife;

    fragColor = color;
}
