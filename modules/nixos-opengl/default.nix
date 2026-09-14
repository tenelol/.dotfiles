{
  delib,
  host,
  pkgs,
  ...
}:
delib.module {
  name = "nixos.opengl";

  options = delib.singleEnableOption (!host.isServer);

  nixos.ifEnabled = {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        mesa
        libglvnd
        libGL
        libGLU
      ];
      extraPackages32 = with pkgs; [
        pkgsi686Linux.mesa
        pkgsi686Linux.libglvnd
      ];
    };

    environment.systemPackages = with pkgs; [
      mesa-demos
      vulkan-tools
    ];
  };
}
