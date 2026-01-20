{ delib, lib, pkgs, ... }:
delib.module {
  name = "nixos.steam";

  nixos.always =
    { myconfig, ... }:
    lib.mkIf (myconfig.host.name == "nvidia-desktop") {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia.open = true;
    hardware.nvidia.modesetting.enable = true;

    programs.xwayland.enable = true;

    environment.systemPackages = with pkgs; [
      xwayland-satellite
    ];

    services.udev.extraRules = ''
      SUBSYSTEM=="input", ATTRS{idVendor}=="26ce", ATTRS{idProduct}=="01a2", ENV{ID_INPUT_JOYSTICK}="0", ENV{ID_INPUT_KEYBOARD}="0"
    '';
  };
}
