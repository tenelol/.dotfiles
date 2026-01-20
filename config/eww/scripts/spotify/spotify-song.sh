#!/usr/bin/env bash

if ! command -v playerctl >/dev/null 2>&1; then
  echo "playerctl missing"
  exit 0
fi

if ! playerctl -p spotify status >/dev/null 2>&1; then
  echo "No player"
  exit 0
fi

song="$(playerctl -p spotify metadata --format "{{ title }}" 2>/dev/null)"
if [ -z "$song" ]; then
  echo "Paused"
  exit 0
fi

if [ ${#song} -gt 22 ]; then
  song="${song:0:22}.."
fi

echo "$song"
