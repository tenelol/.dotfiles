// Animated font zoom. Ghostty swaps in the reflowed frame at the new size at
// once and keeps no copy of the old one, so this scales the new frame to the
// old cell size around the old cursor and eases it back to 1:1 on the new
// cursor. Reflowed lines still jump; only the size change is animated.

const float DURATION = 0.2;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    float ratio = hudZoomRatio();
    float t = (iTime - iTimeCursorChange) / DURATION;
    if (ratio == 1.0 || t >= 1.0) {
        return;
    }

    float ease = hudEaseOut(t);
    float scale = mix(ratio, 1.0, ease);
    // Mapping cursor to cursor keeps the left padding in place too, since the
    // cursor column sits the same number of cells from it at both sizes.
    vec2 from = hudCellCenter(iPreviousCursor);
    vec2 to = hudCellCenter(iCurrentCursor);
    vec2 anchor = mix(from, to, ease);
    vec2 source = to + (fragCoord - anchor) / scale;
    // Shrinking reveals the edges; clamping repeats the padding background.
    vec2 texel = 0.5 / iResolution.xy;
    fragColor = texture(iChannel0, clamp(source / iResolution.xy, texel, 1.0 - texel));
}
