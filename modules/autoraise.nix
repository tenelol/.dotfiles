{
  delib,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
in
delib.module {
  name = "autoraise";

  options = delib.singleEnableOption false;

  darwin.ifEnabled = lib.mkIf isDarwinDesktop {
    launchd.user.agents.autoraise = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.autoraise}/bin/autoraise"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        EnvironmentVariables = {
          USER = profile.username;
          HOME = homeDir;
        };
      };

      managedBy = "autoraise";
    };
  };

  home.ifEnabled = lib.mkIf isDarwinDesktop {
    home.packages = [ pkgs.autoraise ];

    xdg.configFile."AutoRaise/config".source = ../config/autoraise/config;
  };
}
