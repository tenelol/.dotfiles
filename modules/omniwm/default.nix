{
  delib,
  desktopSelection,
  hostTraits,
  hm,
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
    launchd.agents.omniwm = {
      enable = true;
      config = {
        ProgramArguments = [ "/Applications/OmniWM.app/Contents/MacOS/OmniWM" ];
        # Restart only after a crash. OmniWM exits cleanly when it finds another
        # instance (or is quit), and an unconditional KeepAlive turned that into
        # an endless "competing window manager" dialog loop.
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        RunAtLoad = true;
        ProcessType = "Interactive";
        StandardOutPath = "/tmp/omniwm.log";
        StandardErrorPath = "/tmp/omniwm.err.log";
      };
    };
    home.activation.configureOmniwm = hm.dag.entryBetween [ "setupLaunchAgents" ] [ "linkGeneration" ] ''
      $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./files/apply-rift-preset.py} \
        "$HOME/.config/omniwm/settings.toml" ${./files/rift-preset.json}
    '';
    home.activation.registerOmniwm = hm.dag.entryAfter [ "setupLaunchAgents" ] ''
      $DRY_RUN_CMD /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f /Applications/OmniWM.app
    '';
  };
}
