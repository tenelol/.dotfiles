{
  delib,
  hm,
  host,
  hostLib,
  lib,
  pkgs,
  ...
}:
let
  baseConfig = builtins.readFile ../config/niri/config.kdl;
  hostOverlay =
    if host.name == "nvidia-desktop" then builtins.readFile ../config/niri/nvidia-desktop.kdl else "";
in
delib.module {
  name = "niri";

  options = delib.singleEnableOption (hostLib.isLinuxDesktop host);

  home.ifEnabled = {
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
      baseConfig + lib.optionalString (hostOverlay != "") "\n" + hostOverlay;
  };
}
