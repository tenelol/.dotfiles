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

query_focused_workspace() {
  "$RIFT_CLI" query workspaces 2>/dev/null \
    | tr '{' '\n' \
    | sed -nE 's/.*"index"[[:space:]]*:[[:space:]]*([0-9]+).*"is_active"[[:space:]]*:[[:space:]]*true.*/\1/p' \
    | head -n 1 \
    | awk '{ print $1 + 1 }'
}

is_managed_workspace() {
  case "$1" in
    [1-9]) return 0 ;;
    *) return 1 ;;
  esac
}

set_active() {
  is_managed_workspace "$1" || return 0

  "$SKETCHYBAR_BIN" --animate "$ANIMATION" 14 --set "space.$1" \
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

  "$SKETCHYBAR_BIN" --animate "$ANIMATION" "$ANIMATION_DURATION" --set "space.$1" \
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
  for sid in 1 2 3 4 5 6 7 8 9; do
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
