{
  description = "NixOS 26.05 Proxmox cloud-init template image";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      image = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
          {
            proxmox = {
              filenameSuffix = "9001-nixos-26.05-cloud";
              qemuConf = {
                name = "nixos-26.05-cloud";
                cores = 2;
                memory = 2048;
                virtio0 = "local-lvm:vm-9001-disk-0";
                net0 = "virtio=00:00:00:00:00:00,bridge=vmbr0,firewall=1";
              };
              qemuExtraConf = {
                onboot = 0;
                tags = "nixos;template";
              };
              cloudInit = {
                enable = true;
                defaultStorage = "local-lvm";
              };
            };

            virtualisation.diskSize = 8192;

            users.users.tener = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];
              hashedPassword = "!";
            };
            security.sudo.wheelNeedsPassword = false;
            services.openssh.settings = {
              KbdInteractiveAuthentication = false;
              PasswordAuthentication = false;
              PermitRootLogin = "no";
            };

            time.timeZone = "Asia/Tokyo";
            system.stateVersion = "26.05";
          }
        ];
      };
    in
    {
      packages.${system} = {
        default = image.config.system.build.cloudImage;
        cloud-image = image.config.system.build.cloudImage;
      };
      formatter = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        system
      ] (formatterSystem: nixpkgs.legacyPackages.${formatterSystem}.nixfmt-tree);
    };
}
