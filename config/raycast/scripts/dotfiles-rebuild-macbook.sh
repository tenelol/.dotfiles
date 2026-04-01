#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Dotfiles Rebuild Macbook
# @raycast.mode silent

# Optional parameters:
# @raycast.packageName Dotfiles
# @raycast.needsConfirmation false

set -euo pipefail

repo_root="/Users/tener/.dotfiles"
status_file="$(mktemp /tmp/dotfiles-rebuild-status.XXXXXX)"

osascript - "$repo_root" "$status_file" <<'APPLESCRIPT'
on run argv
  set repoRoot to item 1 of argv
  set statusFile to item 2 of argv
  set rebuildCommand to "cd " & quoted form of repoRoot & " && nh darwin switch . -H macbook; printf '%s' $? > " & quoted form of statusFile

  tell application "Terminal"
    do script ""
    delay 0.2
    set rebuildWindow to front window
    do script rebuildCommand in selected tab of rebuildWindow
    set rebuildTab to selected tab of rebuildWindow

    repeat while busy of rebuildTab
      delay 1
    end repeat

    delay 1
  end tell

  repeat until (do shell script "test -f " & quoted form of statusFile & " && cat " & quoted form of statusFile) is not ""
    delay 0.2
  end repeat

  set exitCode to do shell script "cat " & quoted form of statusFile

  if exitCode is "0" then
    tell application "Terminal"
      close rebuildWindow saving no
    end tell
  else
    tell application "Terminal"
      activate
      set index of rebuildWindow to 1
    end tell
  end if

  do shell script "rm -f " & quoted form of statusFile
end run
APPLESCRIPT
