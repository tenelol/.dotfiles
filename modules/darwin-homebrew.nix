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
        "swiftlint"
      ];

      onActivation = {
        autoUpdate = false;
        upgrade = false;
        cleanup = "check";
      };

      masApps = {
        GarageBand = 682658836;
        iMovie = 408981434;
        Keynote = 409183694;
        LINE = 539883307;
        Numbers = 409203825;
        Pages = 409201541;
        RunCat = 1429033973;
      };

      # Keep cross-platform GUI tools in Nix where possible, and reserve
      # Homebrew for cask-first macOS apps or App Store installs.
      casks = [
        "azookey"
        "claude"
        "codex"
        "chatgpt"
        "chatgpt-atlas"
        "cmux"
        "codexbar"
        "codex-app"
        "cursor"
        "discord"
        "docker-desktop"
        "ghostty"
        "google-chrome"
        "macskk"
        "microsoft-office"
        "notion"
        {
          # Temporary: Homebrew marks this cask deprecated because it does not
          # pass the macOS Gatekeeper check.
          name = "qutebrowser";
          args.no_quarantine = true;
        }
        "raycast"
        "slack"
        "spotify"
        "tailscale-app"
        "thebrowsercompany-dia"
        "zed"
        "zen"
      ];
    };
  };
}
