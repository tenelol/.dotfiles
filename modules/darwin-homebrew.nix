{ delib, host, ... }:
delib.module {
  name = "darwin.homebrew";

  options = delib.singleEnableOption (
    builtins.match ".*-darwin" host.system != null && !host.isServer
  );

  darwin.ifEnabled = {
    homebrew = {
      enable = true;
      enableFishIntegration = true;

      onActivation = {
        autoUpdate = true;
        upgrade = true;
        cleanup = "check";
      };

      casks = [
        "ghostty"
        "raycast"
      ];
    };
  };
}
