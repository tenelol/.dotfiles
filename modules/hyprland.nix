{
  delib,
  host,
  lib,
  ...
}:
let
  isLinuxDesktop = !host.isServer && builtins.match ".*-linux" host.system != null;
  baseConfig = builtins.readFile ./hyprland/files/hyprland.conf;
  displayConfig =
    if host.name == "nvidia-desktop" then
      builtins.readFile ./hyprland/files/nvidia-desktop.conf
    else
      "monitor = ,preferred,auto,1\n";
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
    xdg.configFile."hypr/hyprland.conf".text = displayConfig + "\n" + baseConfig;
  };
}
