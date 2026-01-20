{ delib, pkgs, ... }:
delib.module {
  name = "nixos.incus";

  options = delib.singleEnableOption false;

  nixos.ifEnabled = {
    environment.systemPackages = with pkgs; [
      zstd
    ];

    networking = {
      nftables.enable = true;
      firewall = {
        enable = true;
        backend = "nftables";
      };
    };

    virtualisation.incus = {
      enable = true;
      socketActivation = true;

      preseed = {
        config = { };

        networks = [
          {
            config = {
              "ipv4.address" = "auto";
              "ipv6.address" = "auto";
            };
            description = "";
            name = "incusbr0";
            type = "bridge";
          }
        ];

        storage_pools = [
          {
            config = { };
            description = "";
            name = "default";
            driver = "btrfs";
          }
        ];

        profiles = [
          {
            config = { };
            description = "";
            devices = {
              eth0 = {
                name = "eth0";
                network = "incusbr0";
                type = "nic";
              };
              root = {
                path = "/";
                pool = "default";
                type = "disk";
              };
            };
            name = "default";
          }
        ];

        projects = [ ];
        cluster = null;
      };
    };

    users.users.root = {
      subUidRanges = [
        {
          startUid = 1000000;
          count = 1000000000;
        }
      ];

      subGidRanges = [
        {
          startGid = 1000000;
          count = 1000000000;
        }
      ];
    };
  };
}
