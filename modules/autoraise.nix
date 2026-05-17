{
  delib,
  host,
  pkgs,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
in
delib.module {
  name = "autoraise";

  options = delib.singleEnableOption false;

  darwin.ifEnabled = {
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

  home.ifEnabled = {
    home.packages = [ pkgs.autoraise ];

    xdg.configFile."AutoRaise/config".source = ../config/autoraise/config;
  };
}
