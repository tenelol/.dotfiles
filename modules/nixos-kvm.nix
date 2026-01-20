{ delib, lib, ... }:
delib.module {
  name = "nixos.kvm";

  options = delib.singleEnableOption false;

  nixos.ifEnabled = {
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;

    users.users.tener.extraGroups = lib.mkAfter [ "kvm" "libvirtd" ];
  };
}
