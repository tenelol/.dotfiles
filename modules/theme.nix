{
  delib,
  host,
  hm,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "theme";

  options =
    with delib;
    moduleOptions {
      wallpaper = strOption "Indigo.png";
    };

  home.always =
    { myconfig, ... }:
    lib.mkIf (!host.isServer) (
      lib.mkMerge [
        {
          # Keep a stable target path so desktop components can switch rice without
          # knowing the underlying wallpaper file name.
          xdg.configFile = {
            "theme/wallpaper.png".source = ../img + "/${myconfig.theme.wallpaper}";
            "wallpapers".source = ../img;
          };
        }

        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          home.file.".local/bin/apply-theme-wallpaper" = {
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

              if ! ${pkgs.procps}/bin/pgrep -x swww-daemon >/dev/null 2>&1; then
                ${pkgs.swww}/bin/swww-daemon >/dev/null 2>&1 &
              fi

              i=0
              while [ "$i" -lt 20 ]; do
                if ${pkgs.swww}/bin/swww query >/dev/null 2>&1; then
                  break
                fi
                i=$((i + 1))
                ${pkgs.coreutils}/bin/sleep 0.1
              done

              exec ${pkgs.swww}/bin/swww img "$wallpaper" --transition-type none
            '';
          };

          home.activation.applyThemeWallpaper = hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD "$HOME/.local/bin/apply-theme-wallpaper" || true
          '';
        })
      ]
    );
}
