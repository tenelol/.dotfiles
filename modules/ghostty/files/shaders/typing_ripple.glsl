// A small ripple from the last typed character once typing stops. The shader
// only sees the latest cursor change, so "finished" means either the last
// change was a typed advance and the cursor has since sat still, or the cursor
// just went from a bar to a block (leaving Neovim insert mode). Each keystroke
// resets the clock, so nothing fires mid-burst.

const float IDLE = 0.25;
const float LEAVE_DELAY = 0.02;
const float MAX_ADVANCE_CELLS = 1.2;
// Smaller than the focus ripple because it fires far more often.
const float SCALE = 0.6;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
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
    if (t <= 0.0 || t >= HUD_WAVE_DURATION) {
        return;
    }

    // The last typed character: the cell the bar just left, or the block's own
    // cell (Neovim's Esc parks the block on the last typed character).
    vec2 origin = typed
        ? vec2(iPreviousCursor.x + advance.x * 0.5, iPreviousCursor.y - cellHeight * 0.5)
        : hudCellCenter(iCurrentCursor);
    vec2 offset = fragCoord - origin;
    if (length(offset) > hudWaveRadius(t, cellHeight, SCALE) + HUD_WAVE_WIDTH * SCALE * 3.0) {
        return;
    }

    fragColor = vec4(hudShockwave(base.rgb, uv, offset, t, cellHeight, SCALE), base.a);
}
