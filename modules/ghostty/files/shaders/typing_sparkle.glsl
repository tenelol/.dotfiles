// A little star twinkles beside the last typed character once typing stops,
// with two smaller ones popping after it. The trigger is typing_ripple's: the
// last cursor change was a typed advance and the cursor has since sat still,
// or the cursor just went from a bar to a block (leaving Neovim insert mode).

const float IDLE = 0.25;
const float LEAVE_DELAY = 0.02;
const float MAX_ADVANCE_CELLS = 1.2;
const float TWINKLE = 0.45;
const float LAST_DELAY = 0.16;
const float REACH_CELLS = 1.6;

// Four-pointed star with concave sides: 1 inside, soft at the edge.
float starShape(vec2 p, float size) {
    p = abs(p) / size;
    return 1.0 - smoothstep(0.75, 1.0, sqrt(p.x) + sqrt(p.y));
}

// One star popping open with a slight turn, then shrinking away.
vec4 twinkle(vec2 p, float size, float t) {
    if (t <= 0.0 || t >= TWINKLE) {
        return vec4(0.0);
    }
    float life = t / TWINKLE;
    float scale = hudEaseOut(life / 0.35) * (1.0 - smoothstep(0.45, 1.0, life));
    p = hudRotate((1.0 - hudEaseOut(life / 0.5)) * 0.7) * p;
    float body = starShape(p, size * scale + 1e-3);
    float core = starShape(p, size * scale * 0.45 + 1e-3);
    float glow = exp(-dot(p, p) / (size * size * 0.5)) * scale * 0.35;
    vec3 color = mix(iPalette[3], HUD_FLASH, 0.35 + core * 0.65);
    return vec4(color, hudSaturate(body + glow));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    if (iFocus == 0 || iCursorVisible == 0 || hudCellResized()) {
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
    if (t <= 0.0 || t >= TWINKLE + LAST_DELAY) {
        return;
    }

    vec2 origin = typed
        ? vec2(iPreviousCursor.x + advance.x * 0.5, iPreviousCursor.y - cellHeight * 0.5)
        : hudCellCenter(iCurrentCursor);
    vec2 p = (fragCoord - origin) / cellHeight;
    if (length(p) > REACH_CELLS) {
        return;
    }

    // Offsets and sizes in cell heights: one star off the glyph's upper right
    // corner, two small companions around it.
    vec4 star = twinkle(p - vec2(0.42, 0.62), 0.42, t);
    vec4 left = twinkle(p - vec2(-0.38, 0.86), 0.2, t - 0.09);
    vec4 right = twinkle(p - vec2(0.92, 0.12), 0.16, t - LAST_DELAY);

    vec3 color = base.rgb;
    color = mix(color, star.rgb, star.a);
    color = mix(color, left.rgb, left.a);
    color = mix(color, right.rgb, right.a);
    float alpha = max(star.a, max(left.a, right.a));

    fragColor = vec4(color, max(base.a, alpha));
}
