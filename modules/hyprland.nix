{ delib, host, ... }:
delib.module {
  name = "hyprland";

  options = delib.singleEnableOption (
    host.name == "nixos" || host.name == "nvidia-desktop"
  );

  home.ifEnabled = {
    xdg.configFile."hypr" = {
      source = ../config/hypr;
      force = true;
    };
  };
}
