// Lock-on reticle for long cursor jumps. Four corner brackets spin in from a
// wide frame and snap around the landing cell; at the moment of lock the cell
// flashes and a refracting shockwave rolls outward.

const float DURATION = 0.80;
const float LOCK_TIME = 0.24;
const float MIN_JUMP_CELLS = 7.0;
const float START_SCALE = 4.0;
const float START_TURN = 0.9;
const float BRACKET_PAD = 3.0;
const float BRACKET_WIDTH = 2.0;
const float BRACKET_ARM = 0.45;
const float WOBBLE_FREQUENCY = 42.0;
const float WOBBLE_DAMPING = 14.0;
const float WOBBLE_AMOUNT = 0.22;
const float WAVE_DURATION = 0.48;
const float WAVE_REACH = 7.0;
const float WAVE_WIDTH = 16.0;
const float WAVE_STRENGTH = 12.0;

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float h = saturate(dot(p - a, ab) / max(dot(ab, ab), 1e-4));
    return length(p - a - ab * h);
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

    float cellHeight = max(iCurrentCursor.w, 1.0);
    vec2 to = iCurrentCursor.xy + vec2(iCurrentCursor.z, -iCurrentCursor.w) * 0.5;
    vec2 from = iPreviousCursor.xy + vec2(iPreviousCursor.z, -iPreviousCursor.w) * 0.5;
    if (length(to - from) < MIN_JUMP_CELLS * cellHeight) {
        return;
    }

    // Bar cursors are thin, so frame a full cell instead of the bar itself.
    vec2 cellHalf = vec2(max(iCurrentCursor.z, cellHeight * 0.5), cellHeight) * 0.5;
    vec2 offset = fragCoord - to;
    float dist = length(offset);
    float waveTime = elapsed - LOCK_TIME;
    float waveRadius = WAVE_REACH * cellHeight * (1.0 - pow(1.0 - saturate(waveTime / WAVE_DURATION), 3.0));
    if (dist > START_SCALE * length(cellHalf) * 1.5 && dist > waveRadius + WAVE_WIDTH * 3.0) {
        return;
    }

    vec3 color = base.rgb;
    float alpha = 0.0;

    // Refracting shockwave released at lock time.
    if (waveTime > 0.0 && waveTime < WAVE_DURATION) {
        float waveFade = 1.0 - waveTime / WAVE_DURATION;
        float ring = exp(-pow((dist - waveRadius) / WAVE_WIDTH, 2.0));
        vec2 push = dist > 1e-3 ? offset / dist : vec2(0.0);
        vec2 warpedUv = clamp(uv - push * ring * WAVE_STRENGTH * waveFade / iResolution.xy, vec2(0.0), vec2(1.0));
        color = mix(color, texture(iChannel0, warpedUv).rgb, ring * waveFade);
        color += iPalette[4] * ring * waveFade * 0.10;
    }

    // Brackets: rotate the pixel into the reticle frame, fold into one quadrant
    // and measure the distance to a single L-shaped corner.
    // The frame accelerates in like a homing reticle, then the impact
    // squeezes it past the cell and it rings out on a damped wobble.
    float approach = saturate(elapsed / LOCK_TIME);
    float homing = approach * approach;
    float wobble = waveTime > 0.0 ? sin(waveTime * WOBBLE_FREQUENCY) * exp(-waveTime * WOBBLE_DAMPING) : 0.0;
    float scale = mix(START_SCALE, 1.0, homing) - wobble * WOBBLE_AMOUNT;
    float turn = START_TURN * (1.0 - homing);
    mat2 rotate = mat2(cos(turn), -sin(turn), sin(turn), cos(turn));
    vec2 frame = cellHalf * scale + BRACKET_PAD;
    vec2 q = abs(rotate * offset);
    float arm = min(frame.x, frame.y) * BRACKET_ARM + 2.0;
    float bracketDist = min(
        sdSegment(q, frame, frame - vec2(arm, 0.0)),
        sdSegment(q, frame, frame - vec2(0.0, arm))
    );
    float bracket = 1.0 - smoothstep(BRACKET_WIDTH * 0.5, BRACKET_WIDTH * 0.5 + 1.2, bracketDist);
    float bracketAlpha = smoothstep(0.0, 0.06, elapsed) * (1.0 - smoothstep(LOCK_TIME + 0.12, DURATION, elapsed));
    vec3 bracketColor = mix(iPalette[4], vec3(1.0), exp(-abs(waveTime) * 18.0) * 0.7);
    alpha += bracket * bracketAlpha * 0.9;
    color += bracketColor * bracket * bracketAlpha * 0.9;

    // Cell flash at the instant of lock.
    if (waveTime > 0.0) {
        vec2 d = abs(offset) - cellHalf;
        float cellGlow = exp(-max(max(d.x, d.y), 0.0) * 0.25) * exp(-waveTime * 10.0);
        alpha += cellGlow * 0.35;
        color += mix(iPalette[4], iCurrentCursorColor.rgb, 0.5) * cellGlow * 0.35;
    }

    fragColor = vec4(min(color, vec3(1.0)), max(base.a, saturate(alpha)));
}
