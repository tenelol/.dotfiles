{ lib, pkgs }:
{
  sketchybarEnv =
    sketchybarTheme:
    let
      values = {
        TRANSPARENT = sketchybarTheme.transparent;
        GLASS_BG = sketchybarTheme.glassBg;
        GLASS_BORDER = sketchybarTheme.glassBorder;
        TEXT = sketchybarTheme.text;
        TEXT_DIM = sketchybarTheme.textDim;
        TEXT_MUTED = sketchybarTheme.textMuted;
        TEXT_STRONG = sketchybarTheme.textStrong;
        ACCENT = sketchybarTheme.accent;
      };
    in
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "${name}=${lib.escapeShellArg value}") values
    )
    + "\n";

  darwinApplyWallpaperActivation = ''
    wallpaper="$(${pkgs.coreutils}/bin/readlink -f "$HOME/.config/theme/wallpaper.png")"

    if [ -f "$wallpaper" ]; then
      $DRY_RUN_CMD /usr/bin/osascript \
        -e 'on run argv' \
        -e 'set wallpaperPath to POSIX file (item 1 of argv)' \
        -e 'tell application "System Events" to set picture of every desktop to wallpaperPath' \
        -e 'end run' \
        "$wallpaper" >/dev/null 2>&1 || true
    fi
  '';

  linuxApplyWallpaperBin = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -eu

      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      if [ ! -d "$runtime_dir" ]; then
        exit 0
      fi

      wayland_display="''${WAYLAND_DISPLAY:-}"
      if [ -n "$wayland_display" ] && [ ! -S "$runtime_dir/$wayland_display" ]; then
        wayland_display=""
      fi

      if [ -z "$wayland_display" ]; then
        for candidate in "$runtime_dir"/wayland-*; do
          if [ -S "$candidate" ]; then
            wayland_display="''${candidate##*/}"
            break
          fi
        done
      fi

      if [ -z "$wayland_display" ]; then
        exit 0
      fi

      export XDG_RUNTIME_DIR="$runtime_dir"
      export WAYLAND_DISPLAY="$wayland_display"
      wallpaper="$(${pkgs.coreutils}/bin/readlink -f "$HOME/.config/theme/wallpaper.png")"

      if ! ${pkgs.procps}/bin/pgrep -x awww-daemon >/dev/null 2>&1; then
        ${pkgs.awww}/bin/awww-daemon >/dev/null 2>&1 &
      fi

      i=0
      while [ "$i" -lt 20 ]; do
        if ${pkgs.awww}/bin/awww query >/dev/null 2>&1; then
          break
        fi
        i=$((i + 1))
        ${pkgs.coreutils}/bin/sleep 0.1
      done

      exec ${pkgs.awww}/bin/awww img "$wallpaper" --transition-type none
    '';
  };
}
