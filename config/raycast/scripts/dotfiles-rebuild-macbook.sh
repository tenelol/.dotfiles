#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Dotfiles: Rebuild macbook
# @raycast.mode compact

# Optional parameters:
# @raycast.packageName Dotfiles
# @raycast.icon laptop
# @raycast.description Open Terminal.app and run nh darwin switch for macbook

set -euo pipefail

osascript <<'APPLESCRIPT'
tell application "Terminal"
  activate
  do script "cd ~/.dotfiles && nh darwin switch . -H macbook"
end tell
APPLESCRIPT

printf 'Opened Terminal and started nh darwin switch . -H macbook\n'
