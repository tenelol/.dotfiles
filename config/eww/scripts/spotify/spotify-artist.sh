#!/usr/bin/env bash

if ! command -v playerctl >/dev/null 2>&1; then
  echo ""
  exit 0
fi

if ! playerctl -p spotify status >/dev/null 2>&1; then
  echo ""
  exit 0
fi

artist="$(playerctl -p spotify metadata --format "{{ artist }}" 2>/dev/null)"
if [ -z "$artist" ]; then
  echo ""
  exit 0
fi

if [ ${#artist} -gt 26 ]; then
  artist="${artist:0:26}..."
fi

echo "$artist"
