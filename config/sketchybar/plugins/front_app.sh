#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
AEROSPACE_BIN="/opt/homebrew/bin/aerospace"

if [ "$SENDER" = "front_app_switched" ] && [ -n "$INFO" ]; then
  app_name="$INFO"
else
  app_name="$("$AEROSPACE_BIN" list-windows --focused --format '%{app-name}' 2>/dev/null)"
fi

[ -n "$app_name" ] || exit 0

"$SKETCHYBAR_BIN" --set "$NAME" label="$app_name"
