#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
PLUGIN_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
STATE_FILE="${TMPDIR:-/tmp}/sketchybar/focused_workspace"
SID="${NAME#space.}"
ANIMATION=tanh
ANIMATION_DURATION=12

. "$PLUGIN_DIR/theme.sh"
. "$PLUGIN_DIR/window-manager.sh"

focused_workspace="$FOCUSED"

if [ -z "$focused_workspace" ] && [ -r "$STATE_FILE" ]; then
  IFS= read -r focused_workspace < "$STATE_FILE"
fi

if [ -z "$focused_workspace" ]; then
  focused_workspace="$(focused_workspace)"
fi

if [ "$SENDER" = "mouse.entered" ] && [ "$SID" != "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" \
    width=28 \
    padding_left=3 \
    padding_right=3 \
    label.width=28 \
    label.align=center \
    background.drawing=on \
    background.height=24 \
    background.corner_radius=12 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=1 \
    background.color="$GLASS_HOVER" \
    background.border_color="$GLASS_BORDER"
  "$SKETCHYBAR_BIN" --animate "$ANIMATION" "$ANIMATION_DURATION" --set "$NAME" \
    label.color="$TEXT"
  exit 0
fi

if [ "$SENDER" = "mouse.exited" ] && [ "$SID" != "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" \
    width=26 \
    padding_left=3 \
    padding_right=3 \
    label.width=26 \
    label.align=center \
    background.drawing=on \
    background.height=24 \
    background.corner_radius=12 \
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
    width=30 \
    padding_left=3 \
    padding_right=3 \
    label.width=30 \
    label.align=center \
    background.drawing=on \
    background.height=24 \
    background.corner_radius=12 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=1 \
    background.color="$ACCENT_SOFT" \
    background.border_color="$ACCENT" \
    label.color="$TEXT_STRONG"
else
  "$SKETCHYBAR_BIN" --animate "$ANIMATION" "$ANIMATION_DURATION" --set "$NAME" \
    width=26 \
    padding_left=3 \
    padding_right=3 \
    label.width=26 \
    label.align=center \
    background.drawing=on \
    background.height=24 \
    background.corner_radius=12 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color="$TRANSPARENT" \
    background.border_color="$TRANSPARENT" \
    label.color="$TEXT_DIM"
fi
