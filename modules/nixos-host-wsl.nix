{
  delib,
  host,
  inputs,
  lib,
  pkgs,
  profile,
  ...
}:
delib.module {
  name = "nixos.host.wsl";

  options = delib.singleEnableOption (host.name == "wsl");

  nixos.always = {
    imports = [
      inputs.nixos-wsl.nixosModules.default
    ];
  };

  nixos.ifEnabled = {
    networking.hostName = "wsl";

    wsl = {
      enable = true;
      defaultUser = profile.username;

      interop = {
        includePath = true;
        register = true;
      };

      ssh-agent.enable = true;

      wslConf = {
        automount = {
          enabled = true;
          root = "/mnt";
          options = "metadata,uid=1000,gid=100,umask=22,fmask=11";
        };

        interop = {
          enabled = true;
          appendWindowsPath = true;
        };

        network = {
          generateHosts = true;
          generateResolvConf = true;
          hostname = "wsl";
        };
      };
    };

    zramSwap.enable = lib.mkForce false;
    services.tailscale.enable = lib.mkForce false;

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

    environment.systemPackages = with pkgs; [
      curl
      unzip
    ];
  };
}
