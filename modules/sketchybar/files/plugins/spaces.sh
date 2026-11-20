#!/bin/sh

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/run/current-system/sw/bin/sketchybar}"
RIFT_CLI="${RIFT_CLI:-/run/current-system/sw/bin/rift-cli}"
JQ="${JQ:-/usr/bin/jq}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar"
FOCUSED_STATE_FILE="$STATE_DIR/focused_workspace"
PREVIOUS_STATE_FILE="$STATE_DIR/previous_workspace"

theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/theme/sketchybar.env"
[ -r "$theme_file" ] && . "$theme_file"

WORKSPACE_ACTIVE="${WORKSPACE_ACTIVE:-0xcff5f7fa}"
WORKSPACE_INACTIVE="${WORKSPACE_INACTIVE:-0x78f5f7fa}"

# Resolve the backend and its workspace list once; this runs on every
# workspace change.
if /usr/bin/pgrep -qx AeroSpace >/dev/null 2>&1 && [ -x /run/current-system/sw/bin/aerospace ]; then
  managed_workspaces="1 2 3 4 5 6 7 8 9"
  focused_workspace="${FOCUSED:-}"
  [ -n "$focused_workspace" ] \
    || focused_workspace="$(/run/current-system/sw/bin/aerospace list-workspaces --focused 2>/dev/null | head -n 1)"
else
  rift_workspaces="$("$RIFT_CLI" query workspaces 2>/dev/null)" || exit 0
  managed_workspaces="$(printf '%s\n' "$rift_workspaces" | "$JQ" -r '.[] | .index + 1')"
  focused_workspace="$(printf '%s\n' "$rift_workspaces" \
    | "$JQ" -r '[.[] | select(.is_active) | .index + 1][0] // empty')"
fi
[ -n "$focused_workspace" ] || exit 0

is_managed_workspace() {
  for workspace_id in $managed_workspaces; do
    [ "$1" = "$workspace_id" ] && return 0
  done

  return 1
}

# Managed workspaces are 1-9 on AeroSpace, so the item's local number always
# equals its id on both backends.
set_color() {
  is_managed_workspace "$1" || return 0

  "$SKETCHYBAR_BIN" --set "space.$1.$1" label.color="$2"
}

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
  for sid in $managed_workspaces; do
    if [ "$sid" = "$focused_workspace" ]; then
      set_color "$sid" "$WORKSPACE_ACTIVE"
    else
      set_color "$sid" "$WORKSPACE_INACTIVE"
    fi
  done
  exit 0
fi

if [ "$previous_workspace" = "$focused_workspace" ]; then
  exit 0
fi

set_color "$previous_workspace" "$WORKSPACE_INACTIVE"
set_color "$focused_workspace" "$WORKSPACE_ACTIVE"
