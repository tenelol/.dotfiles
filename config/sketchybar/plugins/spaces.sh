#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
RIFT_CLI="/opt/homebrew/bin/rift-cli"
STATE_DIR="${TMPDIR:-/tmp}/sketchybar"
STATE_FILE="$STATE_DIR/focused_workspace"
ANIMATION=tanh
ANIMATION_DURATION=12
TRANSPARENT=0x00000000
TEXT_DIM=0xa8f5f7fa
TEXT_STRONG=0xffffffff
ACCENT=0xff8bd5ff
theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/theme/sketchybar.env"
[ -r "$theme_file" ] && . "$theme_file"

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

item_exists() {
  "$SKETCHYBAR_BIN" --query "$(space_item_name "$1")" >/dev/null 2>&1
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
  item_exists "$1" || return 0

  "$SKETCHYBAR_BIN" --animate "$ANIMATION" 14 --set "$(space_item_name "$1")" \
    width=18 \
    padding_left=3 \
    padding_right=3 \
    label.width=18 \
    label.align=center \
    background.drawing=on \
    background.height=3 \
    background.corner_radius=2 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color="$ACCENT" \
    background.border_color="$TRANSPARENT" \
    label.color="$TEXT_STRONG"
}

set_inactive() {
  is_managed_workspace "$1" || return 0
  item_exists "$1" || return 0

  "$SKETCHYBAR_BIN" --animate "$ANIMATION" "$ANIMATION_DURATION" --set "$(space_item_name "$1")" \
    width=18 \
    padding_left=3 \
    padding_right=3 \
    label.width=18 \
    label.align=center \
    background.drawing=on \
    background.height=3 \
    background.corner_radius=2 \
    background.padding_left=0 \
    background.padding_right=0 \
    background.border_width=0 \
    background.color="$TRANSPARENT" \
    background.border_color="$TRANSPARENT" \
    label.color="$TEXT_DIM"
}

focused_workspace="$FOCUSED"
[ -n "$focused_workspace" ] || focused_workspace="$(query_focused_workspace)"
[ -n "$focused_workspace" ] || exit 0

previous_workspace="$PREVIOUS"
if [ -z "$previous_workspace" ] && [ -r "$STATE_FILE" ]; then
  IFS= read -r previous_workspace < "$STATE_FILE"
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$focused_workspace" > "$STATE_FILE"

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
