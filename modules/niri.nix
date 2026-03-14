{ delib, host, ... }:
delib.module {
  name = "niri";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-linux" host.system != null
  );

  home.ifEnabled = {
    xdg.configFile."niri".source = ../config/niri;
  };
}
