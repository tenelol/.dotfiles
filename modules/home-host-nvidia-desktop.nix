{ delib, host, ... }:
delib.module {
  name = "home.host.nvidia-desktop";

  options = delib.singleEnableOption (host.name == "nvidia-desktop");

  home.ifEnabled = {
    programs.fish.shellAliases = {
      niri-mirror = "niri msg output DP-3 on; niri msg output HDMI-A-1 on; niri msg output DP-3 mode 1920x1080@59.934; niri msg output HDMI-A-1 mode 1920x1080@59.934; niri msg output DP-3 scale 1.0; niri msg output HDMI-A-1 scale 1.0; niri msg output DP-3 position set 0 0; niri msg output HDMI-A-1 position set 0 0";
      niri-extend = "niri msg output DP-3 on; niri msg output HDMI-A-1 on; niri msg output DP-3 mode 3840x2160@75.000; niri msg output HDMI-A-1 mode 1920x1080@164.995; niri msg output DP-3 scale 1.5; niri msg output HDMI-A-1 scale 1.0; niri msg output DP-3 position set 0 0; niri msg output HDMI-A-1 position set 2560 540";
    };

    home.sessionVariables = {
      NVIM_DISCORD_PRESENCE = "1";
    };
  };
}
