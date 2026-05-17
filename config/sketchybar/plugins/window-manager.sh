#!/bin/sh

RIFT_CLI="${RIFT_CLI:-/opt/homebrew/bin/rift-cli}"
AEROSPACE_CLI="${AEROSPACE_CLI:-/opt/homebrew/bin/aerospace}"

active_window_manager() {
  if [ -x "$AEROSPACE_CLI" ] && /usr/bin/pgrep -qx AeroSpace >/dev/null 2>&1; then
    printf '%s\n' aerospace
    return
  fi

  if [ -x "$RIFT_CLI" ]; then
    printf '%s\n' rift
    return
  fi

  if [ -x "$AEROSPACE_CLI" ]; then
    printf '%s\n' aerospace
  fi
}

focused_workspace() {
  case "$(active_window_manager)" in
    aerospace)
      "$AEROSPACE_CLI" list-workspaces --focused 2>/dev/null | head -n 1
      ;;
    rift)
      "$RIFT_CLI" query workspaces 2>/dev/null \
        | tr '{' '\n' \
        | sed -nE 's/.*"index"[[:space:]]*:[[:space:]]*([0-9]+).*"is_active"[[:space:]]*:[[:space:]]*true.*/\1/p' \
        | head -n 1 \
        | awk '{ print $1 + 1 }'
      ;;
  esac
}

switch_workspace() {
  workspace="$1"

  case "$(active_window_manager)" in
    aerospace)
      "$AEROSPACE_CLI" summon-workspace "$workspace"
      ;;
    rift)
      workspace_index=$((workspace - 1))
      "$RIFT_CLI" execute workspace switch "$workspace_index"
      ;;
  esac
}
