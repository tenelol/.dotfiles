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

  darwin.ifEnabled =
    { myconfig, ... }:
    let
      theme = myconfig.theme.jankyborders;
    in
    {
      launchd.user.agents.jankyborders = {
        serviceConfig = {
          ProgramArguments = [
            "${pkgs.jankyborders}/bin/borders"
            "style=round"
            "width=8.0"
            "hidpi=on"
            "active_color=${theme.activeColor}"
            "inactive_color=${theme.inactiveColor}"
            "background_color=${theme.backgroundColor}"
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
