#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
YABAI_BIN="/run/current-system/sw/bin/yabai"
SID="${SID:-${NAME#space.}}"
ANIMATION=tanh
ANIMATION_DURATION=12
TRANSPARENT=0x00000000
TEXT=0xeef5f7fa
TEXT_DIM=0xa8f5f7fa
TEXT_STRONG=0xffffffff
ACCENT=0xff8bd5ff

selected="$SELECTED"

selected_is_true() {
  case "$selected" in
    true|on|1|yes) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -z "$selected" ]; then
  selected="$(
    "$YABAI_BIN" -m query --spaces 2>/dev/null \
      | /usr/bin/python3 -c '
import json
import sys

sid = sys.argv[1]
try:
    spaces = json.load(sys.stdin)
except Exception:
    spaces = []

for space in spaces:
    if str(space.get("index")) == sid:
        print("true" if space.get("is-visible") else "false")
        break
' "$SID"
  )"
  selected="${selected:-false}"
fi

if [ "$SENDER" = "mouse.entered" ] && ! selected_is_true; then
  "$SKETCHYBAR_BIN" --set "$NAME" \
    updates=on \
    width=18 \
    padding_left=3 \
    padding_right=3 \
    label.width=18 \
    label.align=center \
    background.drawing=on \
    background.height=3 \
    background.corner_radius=2 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color="$TRANSPARENT" \
    background.border_color="$TRANSPARENT"
  "$SKETCHYBAR_BIN" --animate "$ANIMATION" "$ANIMATION_DURATION" --set "$NAME" \
    label.color="$TEXT"
  exit 0
fi

if [ "$SENDER" = "mouse.exited" ] && ! selected_is_true; then
  "$SKETCHYBAR_BIN" --set "$NAME" \
    updates=on \
    width=18 \
    padding_left=3 \
    padding_right=3 \
    label.width=18 \
    label.align=center \
    background.drawing=on \
    background.height=3 \
    background.corner_radius=2 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color="$TRANSPARENT" \
    background.border_color="$TRANSPARENT"
  "$SKETCHYBAR_BIN" --animate "$ANIMATION" "$ANIMATION_DURATION" --set "$NAME" \
    label.color="$TEXT_DIM"
  exit 0
fi

if selected_is_true; then
  "$SKETCHYBAR_BIN" --animate "$ANIMATION" 14 --set "$NAME" \
    updates=on \
    width=18 \
    padding_left=3 \
    padding_right=3 \
    label.width=18 \
    label.align=center \
    background.drawing=on \
    background.height=3 \
    background.corner_radius=2 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color="$ACCENT" \
    background.border_color="$TRANSPARENT" \
    label.color="$TEXT_STRONG"
else
  "$SKETCHYBAR_BIN" --animate "$ANIMATION" "$ANIMATION_DURATION" --set "$NAME" \
    updates=on \
    width=18 \
    padding_left=3 \
    padding_right=3 \
    label.width=18 \
    label.align=center \
    background.drawing=on \
    background.height=3 \
    background.corner_radius=2 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color="$TRANSPARENT" \
    background.border_color="$TRANSPARENT" \
    label.color="$TEXT_DIM"
fi
