{ delib, host, pkgs, ... }:
delib.module {
  name = "home.host.nixos";

  options = delib.singleEnableOption (host.name == "nixos");

  home.ifEnabled = {
    home.packages = with pkgs; [
      incus
      zstd
    ];
  };
}
