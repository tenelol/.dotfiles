{ delib, pkgs, ... }:
delib.module {
  name = "nixos.opengl";

  options = delib.singleEnableOption true;

  nixos.ifEnabled = {
    # Enable hardware graphics (OpenGL/Vulkan/Mesa)
    hardware.graphics = {
      enable = true;
      enable32Bit = true;

      # Extra packages for better OpenGL support
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

    # Ensure GLX works properly
    environment.systemPackages = with pkgs; [
      mesa-demos  # includes glxinfo, glxgears
      vulkan-tools
    ];

    # Set library path for OpenGL
    environment.variables = {
      LIBGL_DRIVERS_PATH = "${pkgs.mesa}/lib/dri";
    };
  };
}
