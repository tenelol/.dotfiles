{
  delib,
  hm,
  host,
  lib,
  pkgs,
  ...
}:
let
  baseConfig = builtins.readFile ./niri/files/config.kdl;
  hostOverlay =
    if host.name == "nvidia-desktop" then builtins.readFile ./niri/files/nvidia-desktop.kdl else "";
in
delib.module {
  name = "niri";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-linux" host.system != null
  );

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

    home.file.".local/bin/niri-screenshot" = {
      source = ./niri/files/niri-screenshot;
      executable = true;
    };
  };
}
