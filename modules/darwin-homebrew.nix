{
  delib,
  host,
  lib,
  ...
}:
let
  brewInstalled = builtins.pathExists "/opt/homebrew/bin/brew" || builtins.pathExists "/usr/local/bin/brew";
in
delib.module {
  name = "darwin.homebrew";

  options = delib.singleEnableOption (
    builtins.match ".*-darwin" host.system != null && !host.isServer
  );

  darwin.ifEnabled = {
    homebrew = lib.mkIf brewInstalled {
      enable = true;
      enableFishIntegration = true;

      brews = [
        "mas"
      ];

      onActivation = {
        autoUpdate = false;
        upgrade = false;
        cleanup = "check";
      };

      masApps = {
        LINE = 539883307;
      };

      casks = [
        "ghostty"
        "raycast"
        "spotify"
        "slack"
      ];
    };
  };
}
