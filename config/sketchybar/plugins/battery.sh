#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"

percentage="$(/usr/bin/pmset -g batt | /usr/bin/grep -Eo '[0-9]+%' | /usr/bin/cut -d% -f1)"
charging="$(/usr/bin/pmset -g batt | /usr/bin/grep 'AC Power')"

[ -n "$percentage" ] || exit 0

case "$percentage" in
  9[0-9]|100)
    icon=""
    color="0xff79f2c0"
    ;;
  [6-8][0-9])
    icon=""
    color="0xfff5f7fa"
    ;;
  [3-5][0-9])
    icon=""
    color="0xffffd166"
    ;;
  [1-2][0-9])
    icon=""
    color="0xffff9f43"
    ;;
  *)
    icon=""
    color="0xffff6b6b"
    ;;
esac

if [ -n "$charging" ]; then
  icon=""
  color="0xff79f2c0"
fi

"$SKETCHYBAR_BIN" --set "$NAME" \
  icon.drawing=on \
  icon="$icon" \
  icon.font="CaskaydiaCove Nerd Font:Regular:13.0" \
  icon.color="$color" \
  label="${percentage}%" \
  label.color=0xfff5f7fa
