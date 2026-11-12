{
  delib,
  pkgs,
  ...
}:
delib.module {
  name = "minecraft";

  options = delib.singleEnableOption false;

  home.ifEnabled = {
    home.packages = [
      pkgs.prismlauncher
    ];
  };
}
