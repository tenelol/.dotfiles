{
  delib,
  hm,
  host,
  lib,
  pkgs,
  ...
}:
let
  baseConfig = builtins.readFile ../config/niri/config.kdl;
  waybarStartupComment = "// This line starts waybar, a commonly used bar for Wayland compositors.";
  personaStartupComment = "// This line starts the active rice shell.";
  waybarStartup = "spawn-sh-at-startup \"PATH=$HOME/.nix-profile/bin:/run/current-system/sw/bin:$PATH; waybar\"";
  personaStartup = "spawn-sh-at-startup \"PATH=$HOME/.local/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH; persona-quickshell-session start\"";
  fuzzelBind = "    Alt+Space hotkey-overlay-title=\"Run an Application: fuzzel\" { spawn-sh \"PATH=$HOME/.nix-profile/bin:/run/current-system/sw/bin:$PATH; exec fuzzel\"; }";
  personaBind = "    Alt+Space hotkey-overlay-title=\"Run an Application: Persona\" { spawn-sh \"PATH=$HOME/.local/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH; persona-quickshell-session search\"; }";
  hostOverlay =
    if host.name == "nvidia-desktop" then builtins.readFile ../config/niri/nvidia-desktop.kdl else "";
  configFor =
    myconfig:
    let
      personaEnabled = myconfig.persona-quickshell.enable or false;
    in
    if personaEnabled then
      builtins.replaceStrings
        [
          waybarStartupComment
          waybarStartup
          fuzzelBind
        ]
        [
          personaStartupComment
          personaStartup
          personaBind
        ]
        baseConfig
    else
      baseConfig;
in
delib.module {
  name = "niri";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-linux" host.system != null
  );

  home.ifEnabled =
    { myconfig, ... }:
    {
      home.activation.cleanupLegacyNiriDir = hm.dag.entryBefore [ "checkLinkTargets" ] ''
          legacy_niri="$HOME/.config/niri"

          if [ -L "$legacy_niri" ]; then
            target="$(${pkgs.coreutils}/bin/readlink "$legacy_niri")"

            case "$target" in
              /nix/store/*-home-manager-files/.config/niri)
                $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$legacy_niri"
              ;;
          esac
        fi
      '';

      xdg.configFile."niri/config.kdl".text =
        configFor myconfig + lib.optionalString (hostOverlay != "") "\n" + hostOverlay;
    };
}
