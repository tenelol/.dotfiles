#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Ghostty
# @raycast.mode silent

# Optional parameters:
# @raycast.packageName Apps
# @raycast.needsConfirmation false

set -euo pipefail

managed_app="$HOME/Applications/Home Manager Apps/Ghostty.app"
if [ -d "$managed_app" ]; then
  exec open -na "$managed_app"
fi

exec open -na "Ghostty.app"
