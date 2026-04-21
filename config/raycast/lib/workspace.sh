#!/usr/bin/env bash

set -euo pipefail

YABAI_BIN="/run/current-system/sw/bin/yabai"
DRY_RUN="${WORKSPACE_DRY_RUN:-0}"

workspace_log() {
  printf '[workspace] %s\n' "$*" >&2
}

space_keycode() {
  case "$1" in
    1) printf '18' ;;
    2) printf '19' ;;
    3) printf '20' ;;
    4) printf '21' ;;
    5) printf '23' ;;
    6) printf '22' ;;
    7) printf '26' ;;
    8) printf '28' ;;
    9) printf '25' ;;
    *)
      return 1
      ;;
  esac
}

notify_workspace() {
  local title="$1"
  local subtitle="$2"
  local body="$3"

  if [ "$DRY_RUN" = "1" ]; then
    workspace_log "notify title=${title} subtitle=${subtitle} body=${body}"
    return 0
  fi

  /usr/bin/osascript - "$title" "$subtitle" "$body" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)
end run
APPLESCRIPT
}

focus_space() {
  local sid="$1"
  local keycode

  if [ "$DRY_RUN" = "1" ]; then
    workspace_log "focus space ${sid}"
    return 0
  fi

  if "$YABAI_BIN" -m space --focus "$sid" >/dev/null 2>&1; then
    return 0
  fi

  keycode="$(space_keycode "$sid")"
  /usr/bin/osascript -e "tell application \"System Events\" to key code ${keycode} using control down" >/dev/null 2>&1
}

set_space_layout() {
  local sid="$1"
  local layout="$2"

  focus_space "$sid"

  if [ "$DRY_RUN" = "1" ]; then
    workspace_log "set layout ${layout} on space ${sid}"
    return 0
  fi

  "$YABAI_BIN" -m space --layout "$layout" >/dev/null 2>&1 || true
}

app_is_running() {
  local app="$1"
  local result

  result="$(/usr/bin/osascript -e "application \"$app\" is running" 2>/dev/null || printf 'false')"
  [ "$result" = "true" ]
}

launch_app_if_needed() {
  local app="$1"
  shift

  if app_is_running "$app"; then
    if [ "$DRY_RUN" = "1" ]; then
      workspace_log "skip running app ${app}"
    fi
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    workspace_log "launch ${app}: $*"
    return 0
  fi

  "$@" >/dev/null 2>&1
  /bin/sleep 0.8
}
