#!/usr/bin/env bash

if ! command -v playerctl >/dev/null 2>&1; then
  exit 0
fi

playerctl -p spotify play-pause >/dev/null 2>&1
