#!/usr/bin/env bash

if ! command -v pactl >/dev/null 2>&1; then
  exit 0
fi

pactl set-source-mute @DEFAULT_SOURCE@ toggle >/dev/null 2>&1
