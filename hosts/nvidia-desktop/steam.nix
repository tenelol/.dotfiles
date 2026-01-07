{ config, pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Needed for Steam/Proton 32-bit runtime.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # NVIDIA + Wayland support for niri/Hyprland.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = true;
  hardware.nvidia.modesetting.enable = true;

  # Steam is X11; use Xwayland under Wayland compositors.
  programs.xwayland.enable = true;

  # Provide xwayland-satellite for niri.
  environment.systemPackages = with pkgs; [
    xwayland-satellite
  ];
}
