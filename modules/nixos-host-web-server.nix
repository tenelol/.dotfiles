{
  config,
  delib,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
let
  runnerGuard = pkgs.writeShellScript "github-runner-blog-guard" ''
    if [[ "''${GITHUB_REPOSITORY:-}" != "tenelol/blog" ]]; then
      echo "refusing job outside tenelol/blog" >&2
      exit 1
    fi

    if [[ "''${GITHUB_REF:-}" != "refs/heads/main" ]]; then
      echo "refusing job outside refs/heads/main" >&2
      exit 1
    fi
  '';
in
delib.module {
  name = "nixos.host.web-server";

  options = delib.singleEnableOption (host.name == "web-server");

  nixos.ifEnabled = {
    sops.secrets.cloudflare-tunnel-token = {
      sopsFile = ../secrets/web-server/cloudflare-tunnel-token.enc;
      format = "binary";
      owner = "cloudflared";
      group = "cloudflared";
      mode = "0400";
      restartUnits = [ "cloudflared.service" ];
    };

    users.groups = {
      cloudflared = { };
      web-deploy = { };
    };
    users.users = {
      cloudflared = {
        isSystemUser = true;
        group = "cloudflared";
      };
      github-runner = {
        isSystemUser = true;
        group = "web-deploy";
        home = "/var/lib/github-runner-blog";
        createHome = true;
      };
      ${profile.username}.extraGroups = [ "web-deploy" ];
    };

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts = {
        hmp = {
          default = true;
          root = "/var/www/hmp/current";
          locations."/".tryFiles = "$uri $uri/ =404";
        };
        "me.tenelol.dev" = {
          root = "/var/www/me.tenelol.dev/current";
          locations = {
            "/".tryFiles = "$uri.html $uri $uri/ =404";
            "^~ /_next/static/" = {
              tryFiles = "$uri =404";
              extraConfig = ''
                access_log off;
                expires 1y;
                add_header Cache-Control "public, max-age=31536000, immutable";
              '';
            };
            "= /opengraph-image" = {
              tryFiles = "/opengraph-image =404";
              extraConfig = "default_type image/png;";
            };
            "= /twitter-image" = {
              tryFiles = "/twitter-image =404";
              extraConfig = "default_type image/png;";
            };
          };
          extraConfig = ''
            error_page 404 /404.html;
          '';
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/www/hmp 2775 ${profile.username} web-deploy -"
      "d /var/www/me.tenelol.dev 2775 ${profile.username} web-deploy -"
      "d /var/lib/github-runner-blog 0700 github-runner web-deploy -"
    ];

    systemd.services = {
      cloudflared = {
        description = "Cloudflare Tunnel";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "sops-nix.service"
        ];
        serviceConfig = {
          User = "cloudflared";
          Group = "cloudflared";
          ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file ${config.sops.secrets.cloudflare-tunnel-token.path}";
          Restart = "always";
          RestartSec = 5;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
        };
      };

      github-runner-blog = {
        description = "GitHub Actions runner for tenelol/blog";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig.ConditionPathExists = "/var/lib/github-runner-blog/.runner";
        path = with pkgs; [
          bash
          coreutils
          git
          nodejs_22
          pnpm
          rsync
        ];
        environment = {
          ACTIONS_RUNNER_HOOK_JOB_STARTED = runnerGuard;
          HOME = "/var/lib/github-runner-blog";
          RUNNER_ROOT = "/var/lib/github-runner-blog";
        };
        serviceConfig = {
          User = "github-runner";
          Group = "web-deploy";
          WorkingDirectory = "/var/lib/github-runner-blog";
          ExecStart = "${pkgs.github-runner}/bin/Runner.Listener run --startuptype service";
          Restart = "on-failure";
          RestartSec = 5;
          KillSignal = "SIGINT";
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            "/var/lib/github-runner-blog"
            "/var/www/hmp"
            "/var/www/me.tenelol.dev"
          ];
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}
