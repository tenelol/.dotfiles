#!/usr/bin/env bash

if ! command -v pactl >/dev/null 2>&1; then
  echo "images/icons/audio/mute-mic.png"
  exit 0
fi

status="$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}')"
if [ "$status" = "yes" ]; then
  echo "images/icons/audio/mute-mic.png"
else
  echo "images/icons/audio/mic.png"
fi
