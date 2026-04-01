#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Dotfiles: Rebuild macbook
# @raycast.mode compact

# Optional parameters:
# @raycast.packageName Dotfiles
# @raycast.icon laptop
# @raycast.description Run nh darwin switch in Terminal.app and close it when done

set -euo pipefail

osascript <<'APPLESCRIPT'
set rebuildCommand to "cd ~/.dotfiles && nh darwin switch . -H macbook"

tell application "Terminal"
  do script rebuildCommand
  set rebuildTab to selected tab of front window
  activate

  repeat while busy of rebuildTab
    delay 1
  end repeat

  delay 0.2
  set rebuildWindow to first window whose tabs contains rebuildTab

  if (count of tabs of rebuildWindow) is 1 then
    close rebuildWindow saving no
  else
    close rebuildTab saving no
  end if
end tell
APPLESCRIPT

printf 'Opened Terminal, started nh darwin switch . -H macbook, and will close it when finished\n'
