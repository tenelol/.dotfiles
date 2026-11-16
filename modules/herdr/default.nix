{
  delib,
  hostTraits,
  hm,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "herdr";

  options = delib.singleEnableOption hostTraits.desktop;

  home.ifEnabled =
    { myconfig, ... }:
    let
      omniwmColors = myconfig.theme.colors == "omniwm";
    in
    {
      xdg.configFile."herdr/config.toml" = lib.mkIf (!omniwmColors) {
        force = true;
        source = ./files/config.toml;
      };

      # OmniWM App Theming rewrites [theme.custom] in place, so the config is a
      # regular file here. Each switch refreshes everything but that table.
      home.activation.syncHerdrConfig = lib.mkIf omniwmColors (
        hm.dag.entryAfter [ "linkGeneration" ] ''
          $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./files/sync-config.py} \
            ${./files/config.toml} "$HOME/.config/herdr/config.toml"
        ''
      );
    };
}
