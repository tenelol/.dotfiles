{
  description = "Reusable NixOS modules for tenelol infrastructure";

  outputs = { ... }: {
    nixosModules = {
      headless = import ./modules/headless.nix;
      proxmoxGuest = import ./modules/proxmox-guest.nix;
      serverSecurity = import ./modules/server-security.nix;
      default = {
        imports = [
          ./modules/headless.nix
          ./modules/proxmox-guest.nix
          ./modules/server-security.nix
        ];
      };
    };
  };
}
