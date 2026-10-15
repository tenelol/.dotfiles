// Word lock once typing stops: corner brackets snap onto the run of text that
// ends at the last typed character, flash, and a scan line sweeps under it.
// The shader only sees the latest cursor change, so "finished" means either
// the last change was a typed advance and the cursor has since sat still, or
// the cursor just went from a bar to a block (leaving Neovim insert mode).
// The word is found by walking left over cells that contain ink.

const float IDLE = 0.25;
const float LEAVE_DELAY = 0.02;
const float LOCK_TIME = 0.11;
const float DURATION = 0.50;
const float MAX_ADVANCE_CELLS = 1.2;
const int MAX_WORD_CELLS = 24;
const float START_SPREAD = 0.8;
const float PAD = 2.0;
const float BRACKET_WIDTH = 1.8;
const float WOBBLE_FREQUENCY = 40.0;
const float WOBBLE_DAMPING = 14.0;
const float WOBBLE_AMOUNT = 0.3;
const float SCAN_TIME = 0.16;

// Whether a cell holds any glyph: a 3x3 probe catches thin strokes like "i".
bool cellHasInk(vec2 center, vec2 halfSize) {
    vec3 weights = vec3(0.2126, 0.7152, 0.0722);
    float background = dot(iBackgroundColor, weights);
    for (int ix = -1; ix <= 1; ++ix) {
        for (int iy = -1; iy <= 1; ++iy) {
            vec2 p = center + vec2(float(ix) * 0.3, float(iy) * 0.25) * halfSize * 2.0;
            if (dot(texture(iChannel0, p / iResolution.xy).rgb, weights) - background > 0.2) {
                return true;
            }
        }
    }
    return false;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    if (iFocus == 0 || iCursorVisible == 0) {
        return;
    }

    float cellHeight = max(iCurrentCursor.w, 1.0);
    vec2 advance = iCurrentCursor.xy - iPreviousCursor.xy;
    bool typed = iCurrentCursorStyle == CURSORSTYLE_BAR && advance.x >= 1.0 && abs(advance.y) <= 0.5
        && advance.x <= MAX_ADVANCE_CELLS * cellHeight;
    bool leftInsert = iPreviousCursorStyle == CURSORSTYLE_BAR && iCurrentCursorStyle == CURSORSTYLE_BLOCK;
    if (!typed && !leftInsert) {
        return;
    }

    float t = iTime - iTimeCursorChange - (leftInsert ? LEAVE_DELAY : IDLE);
    if (t < 0.0 || t >= DURATION) {
        return;
    }

    // The last typed character: the cell the bar just left, or the block's own
    // cell (Neovim's Esc parks the block on the last typed character).
    float cellWidth = typed ? advance.x : iCurrentCursor.z;
    vec2 cellHalf = vec2(cellWidth, cellHeight) * 0.5;
    vec2 last = typed ? vec2(iPreviousCursor.x, iPreviousCursor.y - cellHeight) + cellHalf : hudCellCenter(iCurrentCursor);
    float right = last.x + cellHalf.x;
    float maxLeft = right - cellWidth * float(MAX_WORD_CELLS);

    // Cheap reject before the word scan: only the line band near the word.
    vec2 spread = vec2(cellWidth, cellHeight) * (START_SPREAD + 1.0);
    if (abs(fragCoord.y - last.y) > cellHalf.y + spread.y + PAD || fragCoord.x > right + spread.x + PAD
        || fragCoord.x < maxLeft - spread.x - PAD) {
        return;
    }

    int cells = 0;
    for (int k = 0; k < MAX_WORD_CELLS; ++k) {
        if (!cellHasInk(last - vec2(cellWidth * float(k), 0.0), cellHalf)) {
            break;
        }
        cells = k + 1;
    }
    if (cells == 0) {
        return;
    }

    float left = right - cellWidth * float(cells);
    vec2 center = vec2((left + right) * 0.5, last.y);
    vec2 rest = vec2((right - left) * 0.5, cellHalf.y) + PAD;
    vec2 offset = fragCoord - center;

    float lockTime = t - LOCK_TIME;
    float homing = hudHoming(t / LOCK_TIME);
    float wobble = hudWobble(lockTime, WOBBLE_FREQUENCY, WOBBLE_DAMPING) * WOBBLE_AMOUNT;
    vec2 frame = rest + vec2(cellWidth, cellHeight) * START_SPREAD * (1.0 - homing) - vec2(cellWidth, cellHeight) * 0.25 * wobble;
    float arm = min(cellHeight * 0.45, rest.x);
    float bracket = hudBrackets(offset, frame, arm, BRACKET_WIDTH);
    float bracketAlpha = smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(LOCK_TIME + 0.1, DURATION, t));
    vec3 bracketColor = mix(hudAccent(), HUD_FLASH, exp(-abs(lockTime) * 18.0) * 0.7);

    // Scan line sweeping left to right under the word at contact.
    float scan = 0.0;
    if (lockTime > 0.0) {
        float head = mix(left, right, hudEaseOut(lockTime / SCAN_TIME));
        float baseline = fragCoord.y - (last.y - cellHalf.y) - 1.0;
        float within = step(left, fragCoord.x) * (1.0 - smoothstep(head - 1.0, head + 1.0, fragCoord.x));
        scan = exp(-baseline * baseline * 0.5) * within * exp(-max(lockTime - SCAN_TIME, 0.0) * 9.0);
    }

    float alpha = hudSaturate(bracket * bracketAlpha * 0.9 + scan * 0.6);
    vec3 color = base.rgb + bracketColor * bracket * bracketAlpha * 0.9 + mix(HUD_FLASH, hudAccent(), 0.5) * scan * 0.6;
    fragColor = vec4(min(color, vec3(1.0)), max(base.a, alpha));
}
