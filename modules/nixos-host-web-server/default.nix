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
  runnerGuard = pkgs.writeShellScript "github-runner-blog-guard.sh" ''
    if [[ "''${GITHUB_REPOSITORY:-}" != "tenelol/blog" ]]; then
      echo "refusing job outside tenelol/blog" >&2
      exit 1
    fi

    if [[ "''${GITHUB_REF:-}" != "refs/heads/main" ]]; then
      echo "refusing job outside refs/heads/main" >&2
      exit 1
    fi
  '';
  todoRunnerGuard = pkgs.writeShellScript "github-runner-todo-guard" ''
    if [[ "''${GITHUB_REPOSITORY:-}" != "tenelol/dpgk-todo" ||
          "''${GITHUB_REF:-}" != "refs/heads/main" ||
          "''${GITHUB_EVENT_NAME:-}" != "push" ]]; then
      echo "refusing non-main push outside tenelol/dpgk-todo" >&2
      exit 1
    fi
  '';
in
delib.module {
  name = "nixos.host.web-server";

  options = delib.singleEnableOption (host.name == "web-server");

  nixos.ifEnabled = {
    sops.secrets.cloudflare-tunnel-token = {
      sopsFile = ../../secrets/web-server/cloudflare-tunnel-token.enc;
      format = "binary";
      owner = "cloudflared";
      group = "cloudflared";
      mode = "0400";
      restartUnits = [ "cloudflared.service" ];
    };

    users.groups = {
      cloudflared = { };
      web-deploy = { };
      todo = { };
      todo-deploy = { };
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
      todo = {
        isSystemUser = true;
        group = "todo";
      };
      github-runner-todo = {
        isSystemUser = true;
        group = "todo-deploy";
        home = "/var/lib/github-runner-todo";
        createHome = true;
      };
      ${profile.username}.extraGroups = [ "web-deploy" ];
    };

    environment.systemPackages = [ pkgs.nodejs_24 pkgs.pnpm ];

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ "todo" ];
      ensureUsers = [
        {
          name = "todo";
          ensurePermissions."todo.*" = "ALL PRIVILEGES";
        }
      ];
      settings.mysqld.bind-address = "127.0.0.1";
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
        "todo.tenelol.dev" = {
          root = "/var/www/todo.tenelol.dev/current";
          locations = {
            "/".tryFiles = "$uri $uri/ /index.html";
            "/api/".proxyPass = "http://127.0.0.1:3000/";
            "/assets/" = {
              tryFiles = "$uri =404";
              extraConfig = ''
                expires 1y;
                add_header Cache-Control "public, immutable";
              '';
            };
          };
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
      "d /var/www/todo.tenelol.dev 2775 ${profile.username} todo-deploy -"
      "d /opt/nest-react-todo 2775 ${profile.username} todo-deploy -"
      "d /var/lib/github-runner-blog 0700 github-runner web-deploy -"
      "d /var/lib/github-runner-todo 0700 github-runner-todo todo-deploy -"
    ];

    systemd.services = {
      todo-backend = {
        description = "Todo API";
        wantedBy = [ "multi-user.target" ];
        requires = [ "mysql.service" ];
        after = [ "mysql.service" ];
        unitConfig.ConditionPathExists = "/opt/nest-react-todo/current/dist/main.js";
        environment = {
          NODE_ENV = "production";
          PORT = "3000";
          BIND_HOST = "127.0.0.1";
          DB_SOCKET = "/run/mysqld/mysqld.sock";
          DB_NAME = "todo";
          DB_USERNAME = "todo";
        };
        serviceConfig = {
          User = "todo";
          Group = "todo";
          WorkingDirectory = "/opt/nest-react-todo/current";
          ExecStartPre = "${pkgs.nodejs_24}/bin/node ./node_modules/typeorm/cli.js migration:run -d dist/data-source.js";
          ExecStart = "${pkgs.nodejs_24}/bin/node dist/main.js";
          Restart = "on-failure";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
        };
      };

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
      github-runner-todo = {
        description = "GitHub Actions runner for tenelol/dpgk-todo";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig.ConditionPathExists = "/var/lib/github-runner-todo/.runner";
        path = with pkgs; [
          bash
          coreutils
          curl
          git
          gnutar
          nodejs_24
          pnpm
          rsync
        ];
        environment = {
          ACTIONS_RUNNER_HOOK_JOB_STARTED = todoRunnerGuard;
          HOME = "/var/lib/github-runner-todo";
          RUNNER_ROOT = "/var/lib/github-runner-todo";
        };
        serviceConfig = {
          User = "github-runner-todo";
          Group = "todo-deploy";
          WorkingDirectory = "/var/lib/github-runner-todo";
          ExecStart = "${pkgs.github-runner}/bin/Runner.Listener run --startuptype service";
          Restart = "on-failure";
          RestartSec = 5;
          KillSignal = "SIGINT";
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            "/var/lib/github-runner-todo"
            "/var/www/todo.tenelol.dev"
            "/opt/nest-react-todo"
          ];
        };
      };
    };

    security.sudo.extraRules = [
      {
        users = [ "github-runner-todo" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl restart todo-backend.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}
