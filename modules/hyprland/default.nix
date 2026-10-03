{
  delib,
  desktopSelection,
  hostTraits,
  host,
  ...
}:
let
  baseConfig = builtins.readFile ./files/hyprland.conf;
  displayConfig =
    if host.name == "nvidia-desktop" then
      builtins.readFile ./files/nvidia-desktop.conf
    else
      "monitor = ,preferred,auto,1\n";
in
delib.scopedModule {
  name = "hyprland";
  scope = hostTraits.linuxDesktop;

  options = delib.moduleOptions {
    enable = delib.readOnly (delib.boolOption desktopSelection.hyprland);
  };

  nixos.ifEnabled = {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };

  home.ifEnabled = {
    xdg.configFile."hypr/hyprland.conf".text = displayConfig + "\n" + baseConfig;
  };
}
