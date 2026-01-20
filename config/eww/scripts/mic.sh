#!/usr/bin/env bash

if ! command -v pactl >/dev/null 2>&1; then
  echo "--"
  exit 0
fi

vol="$(pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $5; exit}')"
if [ -z "$vol" ]; then
  echo "--"
  exit 0
fi

echo "$vol"
