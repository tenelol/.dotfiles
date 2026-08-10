{
  config,
  delib,
  host,
  pkgs,
  ...
}:
let
  dataMount = "/srv/nas-data";
  ums = pkgs.callPackage ../packages/universal-media-server.nix { };
  storageServices = [
    "filebrowser"
    "nextcloud-cron"
    "nextcloud-setup"
    "ums"
  ];
in
delib.module {
  name = "nixos.host.nas";

  options = delib.singleEnableOption (host.name == "nas");

  nixos.ifEnabled = {
    fileSystems.${dataMount} = {
      device = "/dev/disk/by-label/nas-data";
      fsType = "ext4";
      options = [
        "nofail"
        "x-systemd.device-timeout=10s"
      ];
    };

    sops.secrets.nextcloud-admin-password = {
      sopsFile = ../secrets/nas/nextcloud-admin-password.enc;
      format = "binary";
      owner = "nextcloud";
      group = "nextcloud";
      mode = "0400";
    };

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud32;
      hostName = "nas";
      datadir = "${dataMount}/nextcloud-data";
      configureRedis = true;
      database.createLocally = true;
      config = {
        dbtype = "mysql";
        adminuser = "tener";
        adminpassFile = config.sops.secrets.nextcloud-admin-password.path;
      };
      maxUploadSize = "16G";
      settings.trusted_domains = [
        "nas"
        "localhost"
      ];
    };

    services.nginx.virtualHosts.nas.listen = [
      {
        addr = "0.0.0.0";
        port = 8081;
      }
      {
        addr = "[::]";
        port = 8081;
      }
    ];

    services.filebrowser = {
      enable = true;
      openFirewall = true;
      settings = {
        address = "0.0.0.0";
        port = 8080;
        root = dataMount;
        database = "/var/lib/filebrowser/database.db";
        enableThumbnails = true;
      };
    };

    users.groups.nas-media = { };
    users.users.ums = {
      isSystemUser = true;
      group = "nas-media";
      home = "/var/lib/ums";
    };

    systemd.services = {
      ums = {
        description = "Universal Media Server";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = {
          HOME = "/var/lib/ums";
          UMS_MAX_MEMORY = "800M";
        };
        serviceConfig = {
          User = "ums";
          Group = "nas-media";
          ExecStart = "${ums}/bin/ums";
          Restart = "on-failure";
          RestartSec = 5;
          StateDirectory = "ums";
          WorkingDirectory = "/var/lib/ums";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            dataMount
            "/var/lib/ums"
          ];
        };
      };
    }
    // builtins.listToAttrs (
      map (name: {
        inherit name;
        value.unitConfig.RequiresMountsFor = dataMount;
      }) storageServices
    );

    networking.firewall = {
      allowedTCPPorts = [
        5001
        8081
        9001
        9002
      ];
      allowedUDPPorts = [ 1900 ];
    };
  };
}
