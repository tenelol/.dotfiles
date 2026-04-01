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
        RunCat = 1429033973;
      };

      # Keep cross-platform GUI tools in Nix where possible, and reserve
      # Homebrew for cask-first macOS apps or App Store installs.
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
