{ lib, ... }:

{
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  users.users.tener.extraGroups = lib.mkAfter [ "kvm" "libvirtd" ];
}
