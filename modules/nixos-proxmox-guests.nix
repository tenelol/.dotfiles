{
  delib,
  host,
  inputs,
  profile,
  ...
}:
let
  isProxmoxGuest = builtins.elem host.name [
    "nas"
    "web-server"
  ];
in
delib.module {
  name = "nixos.proxmox-guests";

  options = delib.singleEnableOption isProxmoxGuest;

  nixos.always = {
    imports = [
      inputs.sops-nix.nixosModules.sops
      ../shared/nixos/modules/headless.nix
      ../shared/nixos/modules/proxmox-guest.nix
      ../shared/nixos/modules/server-security.nix
    ];
  };

  nixos.ifEnabled = {
    networking.hostName = host.name;
    nix.settings.trusted-users = [
      "root"
      profile.username
    ];

    sops.age.keyFile = "/var/lib/sops-nix/key.txt";

    tenelol.headless.enable = true;
    tenelol.proxmoxGuest.enable = true;
    tenelol.serverSecurity = {
      enable = true;
      adminUsers = [ profile.username ];
      authorizedKeyFiles = [ profile.sshPublicKey ];
    };
  };
}
