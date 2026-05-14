#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
YABAI_BIN="/run/current-system/sw/bin/yabai"
STATE_FILE="${TMPDIR:-/tmp}/sketchybar/focused_workspace"
SID="${NAME#space.}"
ANIMATION=tanh
ANIMATION_DURATION=12
TRANSPARENT=0x00000000
TEXT=0xeef5f7fa
TEXT_DIM=0xa8f5f7fa
TEXT_STRONG=0xffffffff
ACCENT=0xff8bd5ff

focused_workspace="$FOCUSED"

if [ -z "$focused_workspace" ] && [ -r "$STATE_FILE" ]; then
  IFS= read -r focused_workspace < "$STATE_FILE"
fi

if [ -z "$focused_workspace" ]; then
  focused_workspace="$(
    "$YABAI_BIN" -m query --spaces --space 2>/dev/null \
      | sed -nE 's/.*"index"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' \
      | head -n 1
  )"
fi

if [ "$SENDER" = "mouse.entered" ] && [ "$SID" != "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" \
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

if [ "$SENDER" = "mouse.exited" ] && [ "$SID" != "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" \
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

if [ "$SID" = "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --animate "$ANIMATION" 14 --set "$NAME" \
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
