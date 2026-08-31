{
  delib,
  host,
  inputs,
  lib,
  profile,
  ...
}:
let
  isProxmoxGuest = builtins.elem host.name [
    "adguard-home"
    "nas"
    "web-server"
  ];
in
delib.module {
  name = "nixos.proxmox-guests";

  options = delib.singleEnableOption isProxmoxGuest;

  nixos.always = {
    imports = [ inputs.sops-nix.nixosModules.sops ];
  };

  nixos.ifEnabled = {
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

    networking = {
      hostName = host.name;
      useDHCP = lib.mkDefault true;
      firewall.enable = true;
    };

    nix.settings.trusted-users = [
      "root"
      profile.username
    ];

    sops.age.keyFile = "/var/lib/sops-nix/key.txt";

    services = {
      cloud-init.enable = lib.mkForce false;
      qemuGuest.enable = true;
      logind.settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };
      openssh = {
        enable = true;
        openFirewall = true;
        settings = {
          AllowUsers = [ profile.username ];
          KbdInteractiveAuthentication = false;
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
    };

    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };

    users.users.${profile.username}.openssh.authorizedKeys.keys = [ profile.sshPublicKey ];

    security.sudo.extraRules = [
      {
        users = [ profile.username ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
