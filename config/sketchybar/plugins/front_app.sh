#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"

if [ "$SENDER" = "front_app_switched" ] && [ -n "$INFO" ]; then
  app_name="$INFO"
else
  app_name="$(/usr/bin/osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)"
fi

[ -n "$app_name" ] || exit 0

"$SKETCHYBAR_BIN" --set "$NAME" label="$app_name"
