{
  delib,
  host,
  lib,
  ...
}:
let
  isLinuxDesktop = !host.isServer && builtins.match ".*-linux" host.system != null;
in
delib.module {
  name = "hyprland";

  options = delib.singleEnableOption false;

  nixos.ifEnabled = lib.mkIf isLinuxDesktop {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };

  home.ifEnabled = lib.mkIf isLinuxDesktop {
    xdg.configFile."hypr/hyprland.conf".source = ../config/hypr/persona.conf;
  };
}
