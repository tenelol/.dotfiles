#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
PLUGIN_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

. "$PLUGIN_DIR/theme.sh"

if [ "$SENDER" = "front_app_switched" ] && [ -n "$INFO" ]; then
  app_name="$INFO"
else
  app_name="$(
    osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null
  )"
fi

[ -n "$app_name" ] || exit 0

case "$app_name" in
  Finder)
    icon="󰀶"
    icon_color="$ACCENT"
    ;;
  Ghostty|Terminal|iTerm2)
    icon=""
    icon_color="$ACCENT_ALT"
    ;;
  "Zen Browser"|Safari|"Google Chrome"|Arc|Firefox)
    icon="󰖟"
    icon_color="$ACCENT"
    ;;
  Code|Cursor|VSCodium)
    icon="󰨞"
    icon_color="$ACCENT"
    ;;
  Slack|Discord)
    icon="󰍩"
    icon_color="$ACCENT_ALT"
    ;;
  Spotify|Music)
    icon=""
    icon_color="$ACCENT_ALT"
    ;;
  Obsidian|Notion)
    icon="󰈙"
    icon_color="$TEXT_MUTED"
    ;;
  "System Settings"|"System Preferences")
    icon="󰒓"
    icon_color="$TEXT_MUTED"
    ;;
  *)
    icon="󰣆"
    icon_color="$ACCENT"
    ;;
esac

"$SKETCHYBAR_BIN" --set "$NAME" \
  icon="$icon" \
  icon.color="$icon_color" \
  label="$app_name" \
  label.color="$TEXT"
