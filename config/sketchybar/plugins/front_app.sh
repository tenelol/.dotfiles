#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
YABAI_BIN="/run/current-system/sw/bin/yabai"

if [ "$SENDER" = "front_app_switched" ] && [ -n "$INFO" ]; then
  app_name="$INFO"
else
  app_name="$(
    "$YABAI_BIN" -m query --windows --window 2>/dev/null \
      | sed -nE 's/.*"app"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
      | head -n 1
  )"
fi

[ -n "$app_name" ] || exit 0

"$SKETCHYBAR_BIN" --set "$NAME" label="$app_name"
