#!/usr/bin/env bash

if ! command -v playerctl >/dev/null 2>&1; then
  echo "images/icons/music/play-button.png"
  exit 0
fi

if ! playerctl -p spotify status >/dev/null 2>&1; then
  echo "images/icons/music/play-button.png"
  exit 0
fi

status="$(playerctl -p spotify status 2>/dev/null)"
if [ "$status" = "Playing" ]; then
  echo "images/icons/music/pause-button.png"
else
  echo "images/icons/music/play-button.png"
fi
