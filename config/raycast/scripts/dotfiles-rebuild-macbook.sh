#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Dotfiles: Rebuild macbook
# @raycast.mode compact

# Optional parameters:
# @raycast.packageName Dotfiles
# @raycast.icon laptop
# @raycast.description Run nh darwin switch in Terminal.app and close it on success

set -euo pipefail

tmp_script="$(mktemp /tmp/raycast-rebuild-macbook.XXXXXX.sh)"

cat >"$tmp_script" <<'SHELL'
#!/usr/bin/env bash
set -euo pipefail

cd ~/.dotfiles || exit 1

if nh darwin switch . -H macbook; then
  tab_tty="$(tty)"

  /usr/bin/osascript - "$tab_tty" <<'APPLESCRIPT'
on run argv
  set targetTty to item 1 of argv

  tell application "Terminal"
    repeat with w in windows
      repeat with t in tabs of w
        if tty of t is targetTty then
          if (count of tabs of w) is 1 then
            close w saving no
          else
            close t saving no
          end if
          return
        end if
      end repeat
    end repeat
  end tell
end run
APPLESCRIPT
fi

rm -f "$0"
SHELL

chmod +x "$tmp_script"

osascript - "$tmp_script" <<'APPLESCRIPT'
on run argv
  set rebuildScript to item 1 of argv

  tell application "Terminal"
    do script "/bin/bash " & quoted form of rebuildScript
    activate
  end tell
end run
APPLESCRIPT

printf 'Opened Terminal and started nh darwin switch . -H macbook; it will close on success\n'
