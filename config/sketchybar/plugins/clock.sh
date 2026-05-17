#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
PLUGIN_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

. "$PLUGIN_DIR/theme.sh"

hour="$(/bin/date '+%H')"
clock_text="$(LC_TIME=en_US.UTF-8 LANG=en_US.UTF-8 /bin/date '+%a %-d %b %H:%M')"

if [ "$hour" -ge 6 ] && [ "$hour" -lt 18 ]; then
  icon="󰖨"
  icon_color="$WARNING"
else
  icon="󰖔"
  icon_color="$ACCENT"
fi

"$SKETCHYBAR_BIN" --set "$NAME" \
  icon="$icon" \
  icon.color="$icon_color" \
  label="$clock_text"
