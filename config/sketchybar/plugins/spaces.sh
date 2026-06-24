#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
RIFT_CLI="/opt/homebrew/bin/rift-cli"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar"
FOCUSED_STATE_FILE="$STATE_DIR/focused_workspace"
PREVIOUS_STATE_FILE="$STATE_DIR/previous_workspace"

theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/theme/sketchybar.env"
[ -r "$theme_file" ] && . "$theme_file"

WORKSPACE_ACTIVE="${WORKSPACE_ACTIVE:-0xcff5f7fa}"
WORKSPACE_INACTIVE="${WORKSPACE_INACTIVE:-0x78f5f7fa}"

aerospace_running() {
  /usr/bin/pgrep -qx AeroSpace >/dev/null 2>&1 && [ -x /opt/homebrew/bin/aerospace ]
}

managed_workspaces() {
  if aerospace_running; then
    printf '%s\n' "1 2 3 4 5 6 7 8 9"
  else
    printf '%s\n' "1 2 3 4 5"
  fi
}

space_item_name() {
  workspace_id="$1"
  local_workspace=$(( (workspace_id - 1) % 9 + 1 ))

  printf 'space.%s.%s\n' "$workspace_id" "$local_workspace"
}

query_focused_workspace() {
  if aerospace_running; then
    /opt/homebrew/bin/aerospace list-workspaces --focused 2>/dev/null | head -n 1
    return
  fi

  "$RIFT_CLI" query workspaces 2>/dev/null \
    | tr '{' '\n' \
    | sed -nE 's/.*"index"[[:space:]]*:[[:space:]]*([0-9]+).*"is_active"[[:space:]]*:[[:space:]]*true.*/\1/p' \
    | head -n 1 \
    | awk '{ print $1 + 1 }'
}

is_managed_workspace() {
  for workspace_id in $(managed_workspaces); do
    [ "$1" = "$workspace_id" ] && return 0
  done

  return 1
}

set_active() {
  is_managed_workspace "$1" || return 0

  "$SKETCHYBAR_BIN" --set "$(space_item_name "$1")" label.color="$WORKSPACE_ACTIVE"
}

set_inactive() {
  is_managed_workspace "$1" || return 0

  "$SKETCHYBAR_BIN" --set "$(space_item_name "$1")" label.color="$WORKSPACE_INACTIVE"
}

focused_workspace="$FOCUSED"
[ -n "$focused_workspace" ] || focused_workspace="$(query_focused_workspace)"
[ -n "$focused_workspace" ] || exit 0

previous_workspace="$PREVIOUS"
if [ -z "$previous_workspace" ] && [ -r "$FOCUSED_STATE_FILE" ]; then
  IFS= read -r previous_workspace < "$FOCUSED_STATE_FILE"
fi

mkdir -p "$STATE_DIR"
if [ -n "$previous_workspace" ] && [ "$previous_workspace" != "$focused_workspace" ]; then
  printf '%s\n' "$previous_workspace" > "$PREVIOUS_STATE_FILE"
fi
printf '%s\n' "$focused_workspace" > "$FOCUSED_STATE_FILE"

if [ "$REFRESH" = "all" ] || [ -z "$previous_workspace" ]; then
  for sid in $(managed_workspaces); do
    if [ "$sid" = "$focused_workspace" ]; then
      set_active "$sid"
    else
      set_inactive "$sid"
    fi
  done
  exit 0
fi

if [ "$previous_workspace" = "$focused_workspace" ]; then
  exit 0
fi

set_inactive "$previous_workspace"
set_active "$focused_workspace"
