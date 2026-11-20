{
  delib,
  pkgs,
  ...
}:
delib.module {
  name = "nixos.steam";

  options = delib.singleEnableOption false;

  nixos.ifEnabled = {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    environment.systemPackages = with pkgs; [
      xwayland-satellite
    ];

    services.udev.extraRules = ''
      SUBSYSTEM=="input", ATTRS{idVendor}=="26ce", ATTRS{idProduct}=="01a2", ENV{ID_INPUT_JOYSTICK}="0", ENV{ID_INPUT_KEYBOARD}="0"
    '';
  };
}
