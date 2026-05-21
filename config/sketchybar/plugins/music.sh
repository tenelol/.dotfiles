#!/bin/sh

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
TEXT=0xeef5f7fa
TEXT_DIM=0xa8f5f7fa

theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/theme/sketchybar.env"
[ -r "$theme_file" ] && . "$theme_file"

sanitize_track() {
  /usr/bin/tr '\r\n' ' ' | /usr/bin/sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//'
}

spotify_track() {
  /usr/bin/pgrep -qx Spotify || return 1

  /usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null
tell application "Spotify"
  if player state is playing then
    set trackName to name of current track as text
    set artistName to artist of current track as text
    if artistName is "" then
      return trackName
    else
      return artistName & " - " & trackName
    end if
  end if
end tell
APPLESCRIPT
}

music_track() {
  /usr/bin/pgrep -qx Music || return 1

  /usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null
tell application "Music"
  if player state is playing then
    set trackName to name of current track as text
    set artistName to artist of current track as text
    if artistName is "" then
      return trackName
    else
      return artistName & " - " & trackName
    end if
  end if
end tell
APPLESCRIPT
}

track="$(spotify_track | sanitize_track)"

if [ -z "$track" ]; then
  track="$(music_track | sanitize_track)"
fi

if [ -z "$track" ]; then
  "$SKETCHYBAR_BIN" --set "$NAME" drawing=off
  exit 0
fi

"$SKETCHYBAR_BIN" --set "$NAME" \
  drawing=on \
  icon.color="$TEXT_DIM" \
  label="$track" \
  label.color="$TEXT"
