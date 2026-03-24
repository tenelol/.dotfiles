{
  delib,
  hm,
  host,
  pkgs,
  ...
}:
delib.module {
  name = "waybar";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-linux" host.system != null
  );

  home.ifEnabled = {
    home.activation.cleanupLegacyWaybarDir = hm.dag.entryBefore [ "checkLinkTargets" ] ''
      legacy_waybar="$HOME/.config/waybar"

      if [ -L "$legacy_waybar" ]; then
        target="$(${pkgs.coreutils}/bin/readlink "$legacy_waybar")"

        case "$target" in
          /nix/store/*-home-manager-files/.config/waybar)
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$legacy_waybar"
            ;;
        esac
      fi
    '';

    xdg.configFile."waybar/config".source = ../config/waybar/config;
    xdg.configFile."waybar/style.css".source = ../config/waybar/style.css;
  };
}
