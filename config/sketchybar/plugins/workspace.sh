#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
AEROSPACE_BIN="/opt/homebrew/bin/aerospace"
SID="${NAME#space.}"

focused_workspace="${FOCUSED:-$("$AEROSPACE_BIN" list-workspaces --focused --format '%{workspace}' 2>/dev/null)}"

if [ "$SENDER" = "mouse.entered" ] && [ "$SID" != "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" \
    background.color=0x2ad7f7ff \
    background.border_color=0x45d7f7ff \
    label.color=0xffffffff
  exit 0
fi

if [ "$SENDER" = "mouse.exited" ] && [ "$SID" != "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" \
    background.color=0x1affffff \
    background.border_color=0x14ffffff \
    label.color=0xc8f5f7fa
  exit 0
fi

if [ "$SID" = "$focused_workspace" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" \
    background.color=0xffd7f7ff \
    background.border_color=0xffffffff \
    label.color=0xff111318
else
  "$SKETCHYBAR_BIN" --set "$NAME" \
    background.color=0x1affffff \
    background.border_color=0x14ffffff \
    label.color=0xc8f5f7fa
fi
