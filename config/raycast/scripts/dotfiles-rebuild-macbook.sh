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
state_dir="${HOME}/Library/Application Support/dotfiles/raycast"
log_dir="${HOME}/Library/Logs/dotfiles"
lock_dir="${state_dir}/macbook-switch.lock"
pid_file="${state_dir}/macbook-switch.pid"
timestamp="$(/bin/date '+%Y%m%d-%H%M%S')"
job_label="dev.tenelol.dotfiles.macbook-switch.${timestamp}"
log_file="${log_dir}/macbook-switch-${timestamp}.log"
latest_log="${log_dir}/macbook-switch-latest.log"
runner_script="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/dotfiles-rebuild-runner.XXXXXX")"
rebuild_process_pattern='(^|[[:space:]/])(nh[[:space:]]+(os|darwin)[[:space:]]+(build|switch)|darwin-rebuild[[:space:]]+(build|switch)|nixos-rebuild[[:space:]]+(build|switch))([[:space:]]|$)'

notify() {
  /usr/bin/osascript - "$1" "$2" "$3" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)
end run
APPLESCRIPT
}

is_rebuild_running() {
  /usr/bin/pgrep -f "$rebuild_process_pattern" >/dev/null 2>&1
}

detect_target_configuration() {
  local rice wallpaper

  if /usr/bin/pgrep -qx AeroSpace >/dev/null 2>&1 || [ -e "${HOME}/.config/aerospace/aerospace.toml" ]; then
    rice="aerospace"
  else
    wallpaper="$(/usr/bin/readlink "${HOME}/.config/theme/wallpaper.png" 2>/dev/null || true)"
    case "$wallpaper" in
      *redmoon* | *Redmoon* | *RedMoon*)
        rice="redmoon"
        ;;
      *)
        rice="indigo"
        ;;
    esac
  fi

  printf 'macbook-%s\n' "$rice"
}

/bin/mkdir -p "$state_dir" "$log_dir"

target_configuration="$(detect_target_configuration)"

if [ -f "$pid_file" ]; then
  existing_pid="$(<"$pid_file")"
  if [ -n "$existing_pid" ] && /bin/kill -0 "$existing_pid" 2>/dev/null; then
    notify "Dotfiles Rebuild" "Already running" "Another macbook switch is still in progress."
    exit 0
  fi

  /bin/rm -f "$pid_file"
  /bin/rmdir "$lock_dir" 2>/dev/null || true
fi

if is_rebuild_running; then
  notify "Dotfiles Rebuild" "Already running" "Another rebuild or switch is still in progress."
  exit 0
fi

if ! /bin/mkdir "$lock_dir" 2>/dev/null; then
  notify "Dotfiles Rebuild" "Already running" "Another macbook switch is still in progress."
  exit 0
fi

if is_rebuild_running; then
  /bin/rmdir "$lock_dir" 2>/dev/null || true
  notify "Dotfiles Rebuild" "Already running" "Another rebuild or switch is still in progress."
  exit 0
fi

cat >"$runner_script" <<EOF
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(printf '%q' "$repo_root")
lock_dir=$(printf '%q' "$lock_dir")
pid_file=$(printf '%q' "$pid_file")
log_file=$(printf '%q' "$log_file")
latest_log=$(printf '%q' "$latest_log")
target_configuration=$(printf '%q' "$target_configuration")
rebuild_process_pattern=$(printf '%q' "$rebuild_process_pattern")

askpass_script="\$(/usr/bin/mktemp "\${TMPDIR:-/tmp}/dotfiles-askpass.XXXXXX")"
elevation_script="\$(/usr/bin/mktemp "\${TMPDIR:-/tmp}/dotfiles-sudo-wrapper.XXXXXX")"

cleanup() {
  /bin/rm -f "\$askpass_script" "\$elevation_script" "$runner_script"
  /bin/rm -f "\$pid_file"
  /bin/rmdir "\$lock_dir" 2>/dev/null || true
}

notify() {
  /usr/bin/osascript - "\$1" "\$2" "\$3" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)
end run
APPLESCRIPT
}

is_rebuild_running() {
  /usr/bin/pgrep -f "\$rebuild_process_pattern" >/dev/null 2>&1
}

trap cleanup EXIT

printf '%s\n' "\$$" >"\$pid_file"

cat >"\$askpass_script" <<'ASKPASS'
#!/usr/bin/env bash
set -euo pipefail

/usr/bin/osascript <<'APPLESCRIPT'
set promptText to "nh darwin switch を実行するために管理者認証が必要です。"
return text returned of (display dialog promptText with title "Dotfiles Rebuild" default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK" cancel button "Cancel")
APPLESCRIPT
ASKPASS
/bin/chmod 700 "\$askpass_script"

cat >"\$elevation_script" <<'ELEVATION'
#!/usr/bin/env bash
exec /usr/bin/sudo -A "\$@"
ELEVATION
/bin/chmod 700 "\$elevation_script"

{
  printf '[%s] Starting Raycast-driven macbook switch\n' "\$(/bin/date '+%Y-%m-%d %H:%M:%S')"
  printf '[%s] Repo: %s\n' "\$(/bin/date '+%Y-%m-%d %H:%M:%S')" "\$repo_root"
  printf '[%s] Target: %s\n' "\$(/bin/date '+%Y-%m-%d %H:%M:%S')" "\$target_configuration"
} >"\$log_file"

/bin/ln -snf "\$log_file" "\$latest_log"

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export SUDO_ASKPASS="\$askpass_script"

if is_rebuild_running; then
  printf '[%s] Another rebuild or switch is already running\n' "\$(/bin/date '+%Y-%m-%d %H:%M:%S')" >>"\$log_file"
  notify "Dotfiles Rebuild" "Already running" "Another rebuild or switch is still in progress."
  exit 0
fi

if (
  cd "\$repo_root"
  /usr/bin/env HOME="$HOME" USER="$USER" /run/current-system/sw/bin/nh darwin switch . -H "\$target_configuration" -e "\$elevation_script"
) >>"\$log_file" 2>&1; then
  printf '[%s] Switch completed successfully\n' "\$(/bin/date '+%Y-%m-%d %H:%M:%S')" >>"\$log_file"
  notify "Dotfiles Rebuild" "Switch completed" "\$target_configuration rebuild finished successfully."
else
  status=\$?
  printf '[%s] Switch failed with exit code %s\n' "\$(/bin/date '+%Y-%m-%d %H:%M:%S')" "\$status" >>"\$log_file"
  notify "Dotfiles Rebuild" "Switch failed" "Review \$latest_log for details."
  exit "\$status"
fi
EOF

/bin/chmod 700 "$runner_script"

if /bin/launchctl submit -l "$job_label" -- "$runner_script"; then
  notify "Dotfiles Rebuild" "Started in background" "Running nh darwin switch . -H ${target_configuration} without opening Terminal."
else
  /bin/rm -f "$pid_file"
  /bin/rmdir "$lock_dir" 2>/dev/null || true
  /bin/rm -f "$runner_script"
  notify "Dotfiles Rebuild" "Launch failed" "Could not start the background macbook switch."
  exit 1
fi
