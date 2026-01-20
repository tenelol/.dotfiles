#!/usr/bin/env bash

if ! command -v brightnessctl >/dev/null 2>&1; then
  exit 0
fi

current="$(brightnessctl -m | awk -F',' '{print $4}' | tr -d '%')"
if [ -z "$current" ]; then
  exit 0
fi

if [ "$current" -gt 60 ]; then
  brightnessctl set 30% >/dev/null 2>&1
else
  brightnessctl set 80% >/dev/null 2>&1
fi
