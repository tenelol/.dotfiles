#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
PLUGIN_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

. "$PLUGIN_DIR/theme.sh"

battery_status="$(/usr/bin/pmset -g batt)"
percentage="$(printf '%s\n' "$battery_status" | /usr/bin/grep -Eo '[0-9]+%' | /usr/bin/head -n 1 | /usr/bin/cut -d% -f1)"

[ -n "$percentage" ] || exit 0

case "$percentage" in
  9[0-9]|100)
    icon=""
    color="$ACCENT_ALT"
    ;;
  [6-8][0-9])
    icon=""
    color="$TEXT"
    ;;
  [3-5][0-9])
    icon=""
    color="$WARNING"
    ;;
  [1-2][0-9])
    icon=""
    color="$WARNING"
    ;;
  *)
    icon=""
    color="$DANGER"
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
  color="$ACCENT"
fi

case "$percentage" in
  [0-9]|1[0-9])
    background_drawing=on
    background_color="$DANGER_SOFT"
    border_color="$DANGER"
    label_color="$TEXT_STRONG"
    ;;
  2[0-9])
    background_drawing=on
    background_color="$WARNING_SOFT"
    border_color="$WARNING"
    label_color="$TEXT_STRONG"
    ;;
  *)
    background_drawing=on
    background_color="$GLASS_BG_STRONG"
    border_color="$GLASS_BORDER"
    label_color="$TEXT"
    ;;
esac

"$SKETCHYBAR_BIN" --set "$NAME" \
  background.drawing="$background_drawing" \
  background.height=30 \
  background.corner_radius=15 \
  background.border_width=1 \
  background.color="$background_color" \
  background.border_color="$border_color" \
  icon.drawing=on \
  icon="$icon" \
  icon.font="CaskaydiaCove Nerd Font:Regular:14.0" \
  icon.color="$color" \
  label="${percentage}%" \
  label.color="$label_color"
