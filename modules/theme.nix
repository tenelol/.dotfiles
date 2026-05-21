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
      wallpaper = strOption "wallpaper.png";
      sketchybar = {
        transparent = strOption "0x00000000";
        glassBg = strOption "0x260b1018";
        glassBorder = strOption "0x30ffffff";
        text = strOption "0xeef5f7fa";
        textDim = strOption "0xa8f5f7fa";
        textMuted = strOption "0xcff5f7fa";
        textStrong = strOption "0xffffffff";
        accent = strOption "0xff8bd5ff";
      };
      ghostty = {
        foreground = strOption "c0caf5";
        background = strOption "24283b";
        backgroundBlur = intOption (if pkgs.stdenv.hostPlatform.isDarwin then 96 else 64);
        cursor = strOption "7aa2f7";
        selectionForeground = strOption "c0caf5";
        selectionBackground = strOption "364a82";
      };
      jankyborders = {
        activeColor = strOption "gradient(top_left=0xff1e293b,bottom_right=0xffffffff)";
        inactiveColor = strOption "gradient(top_left=0xff334155,bottom_right=0xfff8fafc)";
        backgroundColor = strOption "0x00000000";
      };
    };

  home.always =
    { myconfig, ... }:
    let
      sketchybarTheme = myconfig.theme.sketchybar;
      sketchybarEnv =
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
    in
    lib.mkIf (!host.isServer) (
      lib.mkMerge [
        {
          # Keep a stable target path so desktop components can switch rice without
          # knowing the underlying wallpaper file name.
          xdg.configFile = {
            "theme/wallpaper.png".source = ../img + "/${myconfig.theme.wallpaper}";
            "theme/sketchybar.env".text = sketchybarEnv;
            "wallpapers".source = ../img;
          };
        }

        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          home.activation.applyThemeWallpaper = hm.dag.entryAfter [ "linkGeneration" ] ''
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
        })

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

          home.activation.applyThemeWallpaper = hm.dag.entryAfter [ "linkGeneration" ] ''
            $DRY_RUN_CMD "$HOME/.local/bin/apply-theme-wallpaper" || true
          '';
        })
      ]
    );
}
