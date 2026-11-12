{
  config,
  delib,
  hostTraits,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "nixos.tailscale";

  options =
    with delib;
    moduleOptions {
      enable = boolOption hostTraits.linux;
      # Desktop hosts use resolved, which lets Tailscale install MagicDNS as a
      # routing domain without competing to rewrite /etc/resolv.conf.
      acceptDns = boolOption hostTraits.desktop;
    };

  nixos.ifEnabled = { cfg, ... }: {
    assertions = [
      {
        assertion = !cfg.acceptDns || config.services.resolved.enable;
        message = "MagicDNS requires systemd-resolved; enable services.resolved or disable myconfig.nixos.tailscale.acceptDns.";
      }
    ];

    environment.systemPackages = [ pkgs.tailscale ];
    services.tailscale = {
      enable = true;
      extraSetFlags = lib.optionals cfg.acceptDns [ "--accept-dns=true" ];
    };
  };
}
