{ delib, lib, pkgs, ... }:
delib.module {
  name = "nixos.incus-zstd";

  options = delib.singleEnableOption false;

  nixos.ifEnabled = {
    systemd.services.incus.path = lib.mkAfter [ pkgs.zstd ];
  };
}
