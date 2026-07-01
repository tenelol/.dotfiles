{
  delib,
  host,
  hm,
  lib,
  pkgs,
  ...
}:
let
  themeLib = import ../lib/theme.nix { inherit lib pkgs; };
in
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
        readabilityScrim = floatOption 0.42;
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
      sketchybarEnv = themeLib.sketchybarEnv myconfig.theme.sketchybar;
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
          home.activation.applyThemeWallpaper = hm.dag.entryAfter [
            "linkGeneration"
          ] themeLib.darwinApplyWallpaperActivation;
        })

        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          home.file.".local/bin/apply-theme-wallpaper" = themeLib.linuxApplyWallpaperBin;

          home.activation.applyThemeWallpaper = hm.dag.entryAfter [ "linkGeneration" ] ''
            $DRY_RUN_CMD "$HOME/.local/bin/apply-theme-wallpaper" || true
          '';
        })
      ]
    );
}
