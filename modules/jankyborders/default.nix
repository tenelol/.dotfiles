{
  delib,
  homeDir,
  pkgs,
  hostTraits,
  profile,
  ...
}:
delib.module {
  name = "jankyborders";

  options = delib.singleEnableOption hostTraits.darwinDesktop;

  darwin.ifEnabled =
    { myconfig, ... }:
    let
      theme = myconfig.theme.jankyborders;
    in
    {
      environment.systemPackages = [ pkgs.jankyborders ];

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
}
