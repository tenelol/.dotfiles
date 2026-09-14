{
  delib,
  host,
  lib,
  ...
}:
delib.module {
  name = "nixos.host.adguard-home";

  options = delib.singleEnableOption (host.name == "adguard-home");

  nixos.ifEnabled = {
    networking = {
      # VM 206 stays stopped until the router can reserve this address and
      # advertise AdGuard safely outside its DHCP pool.
      useDHCP = lib.mkForce false;
      interfaces.ens18.ipv4.addresses = [
        {
          address = "192.168.40.206";
          prefixLength = 24;
        }
      ];
      defaultGateway = "192.168.40.1";
      nameservers = [
        "9.9.9.9"
        "149.112.112.112"
      ];
      firewall = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };
    };

    services.adguardhome = {
      enable = true;
      host = "127.0.0.1";
      port = 3000;
      mutableSettings = false;
      settings = {
        dns = {
          bind_hosts = [ "192.168.40.206" ];
          port = 53;
          upstream_dns = [ "https://dns.quad9.net/dns-query" ];
          bootstrap_dns = [
            "9.9.9.9"
            "149.112.112.112"
          ];
          enable_dnssec = true;
          cache_size = 4194304;
        };
        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
          parental_enabled = false;
          safe_search.enabled = false;
        };
        filters = [
          {
            enabled = true;
            name = "AdGuard DNS filter";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          }
        ];
        querylog = {
          enabled = true;
          file_enabled = true;
          interval = "168h";
          size_memory = 1000;
        };
        statistics = {
          enabled = true;
          interval = "24h";
        };
      };
    };
  };
}
