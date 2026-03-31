{
  delib,
  host,
  ...
}:
delib.module {
  name = "darwin.homebrew";

  options = delib.singleEnableOption (
    builtins.match ".*-darwin" host.system != null && !host.isServer
  );

  darwin.ifEnabled = {
    homebrew = {
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
        "chatgpt"
        "chatgpt-atlas"
        "codex-app"
        "ghostty"
        "raycast"
        "spotify"
        "slack"
      ];
    };
  };
}
