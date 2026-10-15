// Palette-colored spark burst from the cursor while typing.
// Adapted from glassesneo/dotfiles typing_micro_sparks.glsl (MIT).

const float DURATION = 0.30;
const int SPARK_COUNT = 10;
const float MIN_DISTANCE = 0.5;
const float MAX_TYPING_DISTANCE = 42.0;
const float BASE_SPEED = 34.0;
const float SPEED_RAND = 80.0;
const float BASE_RADIUS = 2.6;
const float SIZE_RAND = 4.0;
const float GRAVITY = 58.0;
const float FORWARD_BIAS = 14.0;
const float OPACITY = 0.42;

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec3 accentColor(float n) {
    // ANSI 1-6 hold the theme accents.
    return iPalette[1 + int(floor(hash(n) * 6.0))];
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    fragColor = base;

    // Only a bar cursor means text entry; this skips Neovim normal-mode motions.
    if (iFocus == 0 || iCursorVisible == 0 || iCurrentCursorStyle != CURSORSTYLE_BAR) {
        return;
    }

    float elapsed = iTime - iTimeCursorChange;
    if (elapsed >= DURATION) {
        return;
    }

    vec2 prevCenter = iPreviousCursor.xy + vec2(iPreviousCursor.z, -iPreviousCursor.w) * 0.5;
    vec2 curCenter = iCurrentCursor.xy + vec2(iCurrentCursor.z, -iCurrentCursor.w) * 0.5;
    vec2 delta = curCenter - prevCenter;
    float moveDistance = length(delta);
    // Forward, same-line moves are typing; deletions and line jumps stay quiet.
    if (delta.x <= 0.0 || abs(delta.y) > 1.0 || moveDistance < MIN_DISTANCE || moveDistance > MAX_TYPING_DISTANCE) {
        return;
    }

    float life = saturate(elapsed / DURATION);
    float fade = (1.0 - life) * (1.0 - life);

    vec3 color = base.rgb;
    float totalAlpha = 0.0;
    float seed = iTimeCursorChange * 211.7;
    for (int i = 0; i < SPARK_COUNT; ++i) {
        float fi = float(i);
        float angle = hash(seed + fi * 17.0) * 6.2831853;
        float speed = BASE_SPEED + hash(seed + fi * 5.3) * SPEED_RAND;
        float lift = GRAVITY + hash(seed + fi * 7.7) * 70.0;
        float forward = hash(seed + fi * 11.1) * FORWARD_BIAS;
        vec2 sparkCenter = curCenter
            + vec2(cos(angle), sin(angle)) * speed * life
            + vec2(forward * life, 0.0);
        sparkCenter.y -= lift * life * life;

        float sparkRadius = (BASE_RADIUS + hash(seed + fi * 9.1) * SIZE_RAND) * mix(1.0, 0.45, life);
        float dist = length(fragCoord - sparkCenter);
        float core = smoothstep(sparkRadius + 1.2, sparkRadius * 0.22, dist);
        float halo = smoothstep(sparkRadius * 3.0, sparkRadius * 0.65, dist);

        float alpha = (core + halo * 0.30) * fade * OPACITY;
        color += accentColor(seed + fi * 13.0) * alpha;
        totalAlpha += alpha;
    }

    fragColor = vec4(min(color, vec3(1.0)), max(base.a, saturate(totalAlpha)));
}
