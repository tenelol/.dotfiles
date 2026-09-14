{
  config,
  delib,
  host,
  lib,
  pkgs,
  ...
}:
let
  isLinux = builtins.match ".*-linux" host.system != null;
in
delib.module {
  name = "nixos.tailscale";

  options =
    with delib;
    moduleOptions {
      # Keep the existing Linux coverage, while letting WSL use the Windows
      # Tailscale client that owns its DNS configuration.
      enable = boolOption (isLinux && host.name != "wsl");
      # Desktop hosts use resolved, which lets Tailscale install MagicDNS as a
      # routing domain without competing to rewrite /etc/resolv.conf.
      acceptDns = boolOption (!host.isServer);
    };

  nixos.ifEnabled = { myconfig, ... }: {
    assertions = [
      {
        assertion = !myconfig.nixos.tailscale.acceptDns || config.services.resolved.enable;
        message = "MagicDNS requires systemd-resolved; enable services.resolved or disable myconfig.nixos.tailscale.acceptDns.";
      }
    ];

    environment.systemPackages = [ pkgs.tailscale ];
    services.tailscale = {
      enable = true;
      extraSetFlags = lib.optionals myconfig.nixos.tailscale.acceptDns [ "--accept-dns=true" ];
    };
  };
}
