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
  name = "jankyborders";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    launchd.user.agents.jankyborders = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.jankyborders}/bin/borders"
          "style=round"
          "width=4.0"
          "hidpi=on"
          "active_color=gradient(top_left=0xff7e22ce,bottom_right=0xff0e7490)"
          "inactive_color=gradient(top_left=0xff3b0764,bottom_right=0xff164e63)"
          "background_color=0x00000000"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        EnvironmentVariables = {
          USER = profile.username;
          HOME = homeDir;
        };
      };

      managedBy = "jankyborders";
    };
  };

  home.ifEnabled = {
    home.packages = [ pkgs.jankyborders ];
  };
}
