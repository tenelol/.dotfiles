#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
AEROSPACE_BIN="/opt/homebrew/bin/aerospace"
SID="${NAME#space.}"

focused_workspace="${FOCUSED:-$("$AEROSPACE_BIN" list-workspaces --focused --format '%{workspace}' 2>/dev/null)}"

if [ "$SENDER" = "mouse.entered" ] && [ "$SID" != "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" background.color=0x38ffffff
  exit 0
fi

if [ "$SENDER" = "mouse.exited" ] && [ "$SID" != "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" background.color=0x24ffffff
  exit 0
fi

if [ "$SID" = "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" \
    background.color=0x8fffffff \
    label.color=0xff1d1d1f
else
  "$SKETCHYBAR_BIN" --set "$NAME" \
    background.color=0x24ffffff \
    label.color=0xcc1d1d1f
fi
