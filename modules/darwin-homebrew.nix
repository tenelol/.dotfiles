{
  delib,
  host,
  hostLib,
  ...
}:
delib.module {
  name = "darwin.homebrew";

  options = delib.singleEnableOption (hostLib.isDarwinDesktop host);

  darwin.ifEnabled = {
    homebrew = {
      enable = true;
      enableFishIntegration = true;

      onActivation = {
        autoUpdate = false;
        upgrade = false;
        cleanup = "check";
      };

      casks = [
        "ghostty"
        "raycast"
      ];
    };
  };
}
