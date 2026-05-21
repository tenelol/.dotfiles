#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
TEXT=0xeef5f7fa

theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/theme/sketchybar.env"
[ -r "$theme_file" ] && . "$theme_file"

if [ "$SENDER" = "front_app_switched" ] && [ -n "$INFO" ]; then
  app_name="$INFO"
else
  app_name="$(
    osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null
  )"
fi

[ -n "$app_name" ] || exit 0

"$SKETCHYBAR_BIN" --set "$NAME" \
  label="$app_name" \
  label.color="$TEXT"
