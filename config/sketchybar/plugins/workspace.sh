#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
YABAI_BIN="/run/current-system/sw/bin/yabai"
SID="${NAME#space.}"
ANIMATION=tanh
ANIMATION_DURATION=12

focused_workspace="$FOCUSED"

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
    background.height=2 \
    background.corner_radius=2 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color=0x00000000 \
    background.border_color=0x00000000
  "$SKETCHYBAR_BIN" --animate "$ANIMATION" "$ANIMATION_DURATION" --set "$NAME" \
    label.color=0xd8f5f7fa
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
    background.height=2 \
    background.corner_radius=2 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color=0x00000000 \
    background.border_color=0x00000000
  "$SKETCHYBAR_BIN" --animate "$ANIMATION" "$ANIMATION_DURATION" --set "$NAME" \
    label.color=0x9ff5f7fa
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
    background.height=2 \
    background.corner_radius=2 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color=0xffd7f7ff \
    background.border_color=0x00000000 \
    label.color=0xffffffff
else
  "$SKETCHYBAR_BIN" --animate "$ANIMATION" "$ANIMATION_DURATION" --set "$NAME" \
    width=18 \
    padding_left=3 \
    padding_right=3 \
    label.width=18 \
    label.align=center \
    background.drawing=on \
    background.height=2 \
    background.corner_radius=2 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color=0x00000000 \
    background.border_color=0x00000000 \
    label.color=0x9ff5f7fa
fi
