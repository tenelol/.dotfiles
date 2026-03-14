{ delib, host, ... }:
delib.module {
  name = "waybar";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-linux" host.system != null
  );

  home.ifEnabled = {
    xdg.configFile."waybar".source = ../config/waybar;
  };
}
