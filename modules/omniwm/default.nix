{
  delib,
  desktopSelection,
  hostTraits,
  hm,
  inputs,
  lib,
  pkgs,
  profile,
  ...
}:
delib.scopedModule {
  name = "omniwm";
  scope = hostTraits.darwinDesktop;

  options = delib.moduleOptions {
    enable = delib.readOnly (delib.boolOption desktopSelection.omniwm);
  };

  # darwin-installers copies pkgs.omniwm into /Applications.
  darwin.always.nixpkgs.overlays = [ inputs.omniwm.overlays.default ];

  darwin.ifEnabled.home-manager.sharedModules = [ inputs.omniwm.homeManagerModules.default ];

  darwin.ifEnabled.system.activationScripts.preActivation.text = lib.mkAfter ''
    uid="$(/usr/bin/id -u ${profile.username})"

    for label in git.acsandmann.rift org.nixos.rift homebrew.mxcl.rift org.nixos.aerospace org.nixos.autoraise; do
      /bin/launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true
    done
    for process in rift Rift AeroSpace aerospace AutoRaise autoraise; do
      /usr/bin/pkill -u ${profile.username} -x "$process" >/dev/null 2>&1 || true
    done
  '';

  darwin.ifDisabled.system.activationScripts.preActivation.text = lib.mkAfter ''
    uid="$(/usr/bin/id -u ${profile.username})"

    /bin/launchctl bootout "gui/$uid/org.nix-community.home.omniwm" >/dev/null 2>&1 || true
    /usr/bin/pkill -u ${profile.username} -x OmniWM >/dev/null 2>&1 || true
  '';

  home.ifEnabled = {
    # Template for OmniWM App Theming; registering it is a one-time GUI step
    # (docs/notes/macos-wallpaper-theming.md).
    xdg.configFile."omniwm/app-themes/nvim-palette".source = ./files/app-themes/nvim-palette;
    programs.omniwm = {
      enable = true;
      # The signed app lives in /Applications via darwin-installers; a second
      # copy linked into Home Manager Apps would compete as a window manager.
      package = pkgs.emptyDirectory;
      # Values that differ from omniwm.nix's defaults. Lists other than hotkeys
      # replace the defaults whole, so appRules and workspaces are complete.
      # Settings made in the GUI are reverted on the next switch unless added
      # here.
      settings = ./files/settings.toml;
      preserveSettings = [
        # Recolored from the wallpaper by modules/ghostty/files/wallpaper-theme.py.
        "borders.color"
        "borders.gradient"
        # Per-display layout, keyed by this machine's display UUIDs.
        "monitors"
        "routing"
      ];
      # Restart only after a crash. OmniWM exits cleanly when it finds another
      # instance (or is quit), and an unconditional KeepAlive turned that into
      # an endless "competing window manager" dialog loop.
      launchd.keepAlive = {
        Crashed = true;
        SuccessfulExit = false;
      };
    };
    launchd.agents.omniwm.config = {
      Program = lib.mkForce "/Applications/OmniWM.app/Contents/MacOS/OmniWM";
      ProcessType = "Interactive";
    };
    home.activation.registerOmniwm = hm.dag.entryAfter [ "setupLaunchAgents" ] ''
      $DRY_RUN_CMD /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f /Applications/OmniWM.app
    '';
  };
}
