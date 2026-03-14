{
  delib,
  host,
  lib,
  ...
}:
let
  baseConfig = builtins.readFile ../config/niri/config.kdl;
  hostOverlay =
    if host.name == "nvidia-desktop" then
      builtins.readFile ../config/niri/nvidia-desktop.kdl
    else
      "";
in
delib.module {
  name = "niri";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-linux" host.system != null
  );

  home.ifEnabled = {
    xdg.configFile."niri/config.kdl".text =
      baseConfig
      + lib.optionalString (hostOverlay != "") "\n"
      + hostOverlay;
  };
}
