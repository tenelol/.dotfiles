{
  delib,
  homeDir,
  desktopSelection,
  hostTraits,
  hm,
  pkgs,
  profile,
  stopDarwinWindowManager,
  ...
}:
let

  package = pkgs.callPackage ../../packages/rift.nix { };

  agent = {
    serviceConfig = {
      Label = "git.acsandmann.rift";
      ProgramArguments = [
        "${package}/bin/rift"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
      EnvironmentVariables = {
        USER = profile.username;
        HOME = homeDir;
        PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };

    managedBy = "rift";
  };

  cleanupLegacyYabaiConfig = ''
    legacy_yabai="$HOME/.config/yabai"

    if [ -L "$legacy_yabai" ]; then
      target="$(${pkgs.coreutils}/bin/readlink "$legacy_yabai")"

      case "$target" in
        /nix/store/*-home-manager-files/.config/yabai)
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$legacy_yabai"
          ;;
      esac
    fi
  '';

  reloadRift = ''
    uid="$(/usr/bin/id -u ${profile.username})"

    if [ -x /run/current-system/sw/bin/rift-cli ] && /run/current-system/sw/bin/rift-cli query metrics >/dev/null 2>&1; then
      $DRY_RUN_CMD /run/current-system/sw/bin/rift-cli execute config reload >/dev/null 2>&1 \
        || $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$uid/git.acsandmann.rift" >/dev/null 2>&1 \
        || true
    else
      $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$uid/git.acsandmann.rift" >/dev/null 2>&1 || true
    fi

    if [ -x "$HOME/.config/rift/assign-windows" ]; then
      $DRY_RUN_CMD "$HOME/.config/rift/assign-windows" >/dev/null 2>&1 || true
    fi

    if [ -x "$HOME/.config/rift/sketchybar-workspace-subscribe" ]; then
      $DRY_RUN_CMD "$HOME/.config/rift/sketchybar-workspace-subscribe" >/dev/null 2>&1 || true
    fi
  '';

  configFiles = {
    "rift/config.toml".source = ./files/config.toml;
    "rift/assign-windows" = {
      source = ./files/assign-windows;
      executable = true;
    };
    "rift/sketchybar-workspace-subscribe" = {
      source = ./files/sketchybar-workspace-subscribe;
      executable = true;
    };
  };
in
delib.scopedModule {
  name = "rift";
  scope = hostTraits.darwinDesktop;

  options = delib.moduleOptions {
    enable = delib.readOnly (delib.boolOption desktopSelection.rift);
  };

  darwin.always.environment.systemPackages = [ package ];

  darwin.ifEnabled.launchd.user.agents.rift = agent;

  darwin.ifDisabled.system.activationScripts.preActivation.text = stopDarwinWindowManager {
    # org.nixos.rift and homebrew.mxcl.rift are labels of earlier installs.
    labels = [
      "git.acsandmann.rift"
      "org.nixos.rift"
      "homebrew.mxcl.rift"
    ];
    processes = [
      "rift"
      "Rift"
    ];
  };

  home.ifEnabled = {
    home.activation.cleanupLegacyYabaiConfig = hm.dag.entryBefore [
      "checkLinkTargets"
    ] cleanupLegacyYabaiConfig;

    home.activation.reloadRift = hm.dag.entryAfter [ "linkGeneration" ] reloadRift;

    xdg.configFile = configFiles;
  };
}
