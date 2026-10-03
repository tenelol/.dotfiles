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
let
  homeDir = "/Users/${profile.username}";

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

  cleanupLegacyYabai = ''
    uid="$(/usr/bin/id -u ${profile.username})"

    for label in org.nixos.rift homebrew.mxcl.rift org.nixos.aerospace org.nixos.autoraise org.nixos.yabai org.nixos.skhd homebrew.mxcl.yabai homebrew.mxcl.skhd; do
      /bin/launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true
    done

    /usr/bin/pkill -u ${profile.username} -x AeroSpace >/dev/null 2>&1 || true
    /usr/bin/pkill -u ${profile.username} -x aerospace >/dev/null 2>&1 || true
    /usr/bin/pkill -u ${profile.username} -x autoraise >/dev/null 2>&1 || true
    /usr/bin/pkill -u ${profile.username} -x AutoRaise >/dev/null 2>&1 || true
    /usr/bin/pkill -u ${profile.username} -f '[A]pplications/AeroSpace.app/Contents/MacOS/AeroSpace' >/dev/null 2>&1 || true
    /usr/bin/pkill -u ${profile.username} -f '[a]utoraise.*/bin/autoraise' >/dev/null 2>&1 || true
    /usr/bin/pkill -u ${profile.username} -x yabai >/dev/null 2>&1 || true
    /usr/bin/pkill -u ${profile.username} -x skhd >/dev/null 2>&1 || true

    for plist in \
      /Library/LaunchAgents/org.nixos.yabai.plist \
      /Library/LaunchAgents/org.nixos.skhd.plist \
      "${homeDir}/Library/LaunchAgents/org.nixos.yabai.plist" \
      "${homeDir}/Library/LaunchAgents/org.nixos.skhd.plist" \
      "${homeDir}/Library/LaunchAgents/org.nixos.rift.plist" \
      "${homeDir}/Library/LaunchAgents/homebrew.mxcl.rift.plist" \
      "${homeDir}/Library/LaunchAgents/homebrew.mxcl.yabai.plist" \
      "${homeDir}/Library/LaunchAgents/homebrew.mxcl.skhd.plist"; do
      /bin/rm -f "$plist"
    done
  '';

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

  syncSketchybarSubscription = ''
    uid="$(/usr/bin/id -u ${profile.username})"

    $DRY_RUN_CMD /bin/launchctl bootout "gui/$uid/org.nixos.aerospace" >/dev/null 2>&1 || true
    $DRY_RUN_CMD /bin/launchctl bootout "gui/$uid/org.nixos.autoraise" >/dev/null 2>&1 || true
    $DRY_RUN_CMD /usr/bin/pkill -u ${profile.username} -x AeroSpace >/dev/null 2>&1 || true
    $DRY_RUN_CMD /usr/bin/pkill -u ${profile.username} -x aerospace >/dev/null 2>&1 || true
    $DRY_RUN_CMD /usr/bin/pkill -u ${profile.username} -x autoraise >/dev/null 2>&1 || true
    $DRY_RUN_CMD /usr/bin/pkill -u ${profile.username} -x AutoRaise >/dev/null 2>&1 || true
    $DRY_RUN_CMD /usr/bin/pkill -u ${profile.username} -f '[A]pplications/AeroSpace.app/Contents/MacOS/AeroSpace' >/dev/null 2>&1 || true
    $DRY_RUN_CMD /usr/bin/pkill -u ${profile.username} -f '[a]utoraise.*/bin/autoraise' >/dev/null 2>&1 || true

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
  scope = {
    home = hostTraits.darwinDesktop;
  };

  options = delib.moduleOptions {
    enable = delib.readOnly (delib.boolOption desktopSelection.rift);
  };

  darwin.always = lib.mkIf hostTraits.darwinDesktop { environment.systemPackages = [ package ]; };

  darwin.ifEnabled = {
    launchd.user.agents.rift = agent;
    system.activationScripts.cleanupLegacyYabai.text = cleanupLegacyYabai;
  };

  home.ifEnabled = {
    home.activation.cleanupLegacyYabaiConfig = hm.dag.entryBefore [
      "checkLinkTargets"
    ] cleanupLegacyYabaiConfig;

    home.activation.syncRiftSketchybarSubscription = hm.dag.entryAfter [
      "linkGeneration"
    ] syncSketchybarSubscription;

    xdg.configFile = configFiles;
  };
}
