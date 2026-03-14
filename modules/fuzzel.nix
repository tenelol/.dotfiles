{ delib, host, ... }:
delib.module {
  name = "fuzzel";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-linux" host.system != null
  );

  home.ifEnabled = {
    xdg.configFile."fuzzel" = {
      source = ../config/fuzzel;
      recursive = true;
    };
  };
}
