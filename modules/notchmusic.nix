{
  delib,
  host,
  lib,
  pkgs,
  ...
}:
let
  notchMusicPackage = import ../packages/notchmusic.nix {
    inherit pkgs lib;
  };
  appPath = "${notchMusicPackage}/Applications/NotchMusic.app";
in
delib.module {
  name = "notchmusic";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    launchd.user.agents.notchmusic = {
      serviceConfig = {
        Label = "dev.notchmusic.app";
        ProgramArguments = [
          "/usr/bin/open"
          appPath
        ];
        RunAtLoad = true;
        KeepAlive = false;
        ProcessType = "Interactive";
      };

      managedBy = "notchmusic";
    };
  };

  home.ifEnabled = {
    home.packages = [ notchMusicPackage ];
  };
}
