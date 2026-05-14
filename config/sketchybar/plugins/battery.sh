#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"

battery_status="$(/usr/bin/pmset -g batt)"
percentage="$(printf '%s\n' "$battery_status" | /usr/bin/grep -Eo '[0-9]+%' | /usr/bin/head -n 1 | /usr/bin/cut -d% -f1)"

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

case "$battery_status" in
  *"AC Power"*)
    charging=1
    ;;
  *)
    charging=
    ;;
esac

if [ -n "$charging" ]; then
  icon=""
  color="0xff79f2c0"
fi

case "$percentage" in
  [0-9]|1[0-9])
    background_drawing=on
    background_color=0x30ff6b6b
    border_color=0x66ff6b6b
    ;;
  *)
    background_drawing=off
    background_color=0x00000000
    border_color=0x00000000
    ;;
esac

if [ -n "$charging" ]; then
  background_drawing=on
  background_color=0x2079f2c0
  border_color=0x5579f2c0
fi

"$SKETCHYBAR_BIN" --set "$NAME" \
  background.drawing="$background_drawing" \
  background.height=24 \
  background.corner_radius=12 \
  background.border_width=1 \
  background.color="$background_color" \
  background.border_color="$border_color" \
  icon.drawing=on \
  icon="$icon" \
  icon.font="CaskaydiaCove Nerd Font:Regular:13.0" \
  icon.color="$color" \
  label="${percentage}%" \
  label.color=0xfff5f7fa
