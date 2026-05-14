// Cursor smear for Ghostty.
// Uses Ghostty's cursor uniforms to add a short-lived warp and glow after moves.

const float TRAIL_SECONDS = 0.34;
const float RIPPLE_SECONDS = 0.44;
const float TRAIL_WIDTH = 2.65;
const float WARP_PIXELS = 11.0;
const float CHROMA_PIXELS = 2.2;

vec2 cursorCenter(vec4 cursor) {
    return cursor.xy + vec2(cursor.z * 0.5, -cursor.w * 0.5);
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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 resolution = iResolution.xy;
    vec2 uv = fragCoord / resolution;

    vec2 current = cursorCenter(iCurrentCursor);
    vec2 previous = cursorCenter(iPreviousCursor);
    vec2 delta = current - previous;
    float travel = length(delta);

    float age = max(iTime - iTimeCursorChange, 0.0);
    float trailLife = 1.0 - smoothstep(0.0, TRAIL_SECONDS, age);
    float rippleLife = 1.0 - smoothstep(0.02, RIPPLE_SECONDS, age);
    float focus = clamp(float(iFocus), 0.0, 1.0);

    float cell = max(max(iCurrentCursor.z, iCurrentCursor.w), 1.0);
    float width = cell * TRAIL_WIDTH;
    float travelBoost = clamp(travel / 220.0, 0.18, 1.0);

    float along = segmentT(fragCoord, previous, current);
    float trailDist = segmentDistance(fragCoord, previous, current);
    float trailMask = 1.0 - smoothstep(width * 0.25, width, trailDist);
    float tailFade = smoothstep(0.0, 0.18, along) * (1.0 - smoothstep(0.92, 1.0, along));
    float activeTrail = trailMask * tailFade * trailLife * focus;

    vec2 direction = safeNormalize(delta + vec2(0.001, 0.0));
    vec2 normal = vec2(-direction.y, direction.x);

    float wave = sin(trailDist * 0.22 - age * 42.0) * (1.0 - smoothstep(0.0, width, trailDist));
    vec2 warp = direction * activeTrail * WARP_PIXELS * travelBoost;
    warp += normal * wave * trailLife * focus * WARP_PIXELS * 0.45 * travelBoost;

    vec2 fromCursor = fragCoord - current;
    float cursorDistance = length(fromCursor);
    float rippleRing = sin(cursorDistance * 0.18 - age * 48.0);
    float rippleMask = exp(-cursorDistance / max(width * 2.4, 1.0)) * rippleLife * focus;
    warp += safeNormalize(fromCursor) * rippleRing * rippleMask * WARP_PIXELS * 0.55;

    vec2 sampleUv = clamp(uv - warp / resolution, vec2(0.0), vec2(1.0));
    vec2 chroma = direction * activeTrail * CHROMA_PIXELS * travelBoost / resolution;

    vec4 color;
    color.r = texture(iChannel0, clamp(sampleUv + chroma, vec2(0.0), vec2(1.0))).r;
    color.g = texture(iChannel0, sampleUv).g;
    color.b = texture(iChannel0, clamp(sampleUv - chroma, vec2(0.0), vec2(1.0))).b;
    color.a = texture(iChannel0, sampleUv).a;

    vec3 cursorColor = max(iCurrentCursorColor.rgb, vec3(0.18));
    vec3 accent = mix(cursorColor, vec3(0.20, 0.72, 1.0), 0.28);
    float glow = activeTrail * 0.20 + abs(rippleRing) * rippleMask * 0.11;
    color.rgb += accent * glow;

    fragColor = color;
}
