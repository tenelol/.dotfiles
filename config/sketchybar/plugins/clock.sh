#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
clock_text="$(LC_TIME=en_US.UTF-8 LANG=en_US.UTF-8 /bin/date '+%a %b %-d %H:%M')"

"$SKETCHYBAR_BIN" --set "$NAME" label="$clock_text"
