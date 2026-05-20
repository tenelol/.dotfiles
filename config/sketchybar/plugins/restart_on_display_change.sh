#!/bin/sh

STATE_DIR="${TMPDIR:-/tmp}/sketchybar"
STATE_FILE="$STATE_DIR/restart-sketchybar"

case "${SENDER:-}" in
  display_change | system_woke) ;;
  *) exit 0 ;;
esac

mkdir -p "$STATE_DIR"

now="$(/bin/date +%s)"
last=0

if [ -r "$STATE_FILE" ]; then
  IFS= read -r last < "$STATE_FILE"
fi

case "$last" in
  '' | *[!0-9]*) last=0 ;;
esac

if [ "$((now - last))" -lt 3 ]; then
  exit 0
fi

printf '%s\n' "$now" > "$STATE_FILE"

(
  /bin/sleep 1
  uid="$(/usr/bin/id -u)"
  /bin/launchctl kickstart -k "gui/$uid/org.nixos.sketchybar" >/dev/null 2>&1 \
    || /opt/homebrew/bin/sketchybar --reload >/dev/null 2>&1 \
    || true
) >/dev/null 2>&1 &
