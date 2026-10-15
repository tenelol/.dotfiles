// Focus ripple: when Ghostty gains focus, the cursor cell flashes and the same
// refracting shockwave as the jump reticle rolls out from it.

const float DELAY = 0.03;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    fragColor = base;

    float t = iTime - iTimeFocus - DELAY;
    if (iFocus == 0 || iCursorVisible == 0 || t <= 0.0 || t >= HUD_WAVE_DURATION) {
        return;
    }

    float cellHeight = max(iCurrentCursor.w, 1.0);
    vec2 cellHalf = vec2(max(iCurrentCursor.z, cellHeight * 0.5), cellHeight) * 0.5;
    vec2 offset = fragCoord - hudCellCenter(iCurrentCursor);
    if (length(offset) > hudWaveRadius(t, cellHeight) + HUD_WAVE_WIDTH * 3.0 && length(offset) > cellHeight * 2.0) {
        return;
    }

    vec3 color = hudShockwave(base.rgb, uv, offset, t, cellHeight);
    float flash = hudCellFlash(offset, cellHalf, t);
    color += mix(hudAccent(), iCurrentCursorColor.rgb, 0.5) * flash * 0.35;
    fragColor = vec4(min(color, vec3(1.0)), max(base.a, hudSaturate(flash * 0.35)));
}
