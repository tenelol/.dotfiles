{
  delib,
  host,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
in
delib.module {
  name = "rift";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    homebrew = {
      taps = [ "acsandmann/tap" ];
      brews = [ "acsandmann/tap/rift" ];
    };

    launchd.user.agents.rift = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-lc"
          "/opt/homebrew/bin/rift"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        EnvironmentVariables = {
          USER = profile.username;
          HOME = homeDir;
          PATH = "/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
      };

      managedBy = "rift";
    };
  };

  home.ifEnabled = {
    xdg.configFile."rift/config.toml".source = ../config/rift/config.toml;
  };
}
