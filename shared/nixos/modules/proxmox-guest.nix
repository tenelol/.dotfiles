{ config, lib, ... }:
let
  cfg = config.tenelol.proxmoxGuest;
in
{
  options.tenelol.proxmoxGuest.enable = lib.mkEnableOption "Proxmox QEMU guest integration";

  config = lib.mkIf cfg.enable {
    boot = {
      growPartition = true;
      initrd.availableKernelModules = [
        "virtio_blk"
        "virtio_pci"
        "virtio_scsi"
      ];
      kernelModules = [
        "virtio_balloon"
        "virtio_console"
      ];
    };

    networking.useDHCP = lib.mkDefault true;
    services.cloud-init.enable = lib.mkForce false;
    services.qemuGuest.enable = true;
  };
}
