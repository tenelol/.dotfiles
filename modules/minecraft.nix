{ delib, host, pkgs, ... }:
delib.module {
  name = "minecraft";

  options = delib.singleEnableOption (host.name == "nvidia-desktop");

  home.ifEnabled = {
    home.packages = [
      pkgs.prismlauncher
    ];
  };
}
