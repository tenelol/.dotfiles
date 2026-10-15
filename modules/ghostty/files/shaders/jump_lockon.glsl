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
    vec2 to = hudCellCenter(iCurrentCursor);
    if (length(to - hudCellCenter(iPreviousCursor)) < MIN_JUMP_CELLS * cellHeight) {
        return;
    }

    // Bar cursors are thin, so frame a full cell instead of the bar itself.
    vec2 cellHalf = vec2(max(iCurrentCursor.z, cellHeight * 0.5), cellHeight) * 0.5;
    vec2 offset = fragCoord - to;
    float dist = length(offset);
    float waveTime = elapsed - LOCK_TIME;
    if (dist > START_SCALE * length(cellHalf) * 1.5 && dist > hudWaveRadius(waveTime, cellHeight) + HUD_WAVE_WIDTH * 3.0) {
        return;
    }

    // Refracting shockwave released at lock time.
    vec3 color = hudShockwave(base.rgb, uv, offset, waveTime, cellHeight);
    float alpha = 0.0;

    // The frame accelerates in like a homing reticle, then the impact
    // squeezes it past the cell and it rings out on a damped wobble.
    float homing = hudHoming(elapsed / LOCK_TIME);
    float wobble = hudWobble(waveTime, WOBBLE_FREQUENCY, WOBBLE_DAMPING);
    float scale = mix(START_SCALE, 1.0, homing) - wobble * WOBBLE_AMOUNT;
    vec2 frame = cellHalf * scale + BRACKET_PAD;
    vec2 rotated = hudRotate(START_TURN * (1.0 - homing)) * offset;
    float bracket = hudBrackets(rotated, frame, min(frame.x, frame.y) * BRACKET_ARM + 2.0, BRACKET_WIDTH);
    float bracketAlpha = smoothstep(0.0, 0.06, elapsed) * (1.0 - smoothstep(LOCK_TIME + 0.12, DURATION, elapsed));
    vec3 bracketColor = mix(hudAccent(), HUD_FLASH, exp(-abs(waveTime) * 18.0) * 0.7);
    alpha += bracket * bracketAlpha * 0.9;
    color += bracketColor * bracket * bracketAlpha * 0.9;

    // Cell flash at the instant of lock.
    float cellGlow = hudCellFlash(offset, cellHalf, waveTime);
    alpha += cellGlow * 0.35;
    color += mix(hudAccent(), iCurrentCursorColor.rgb, 0.5) * cellGlow * 0.35;

    fragColor = vec4(min(color, vec3(1.0)), max(base.a, hudSaturate(alpha)));
}
