{ pkgs, profile }:
let
  homeDir = "/Users/${profile.username}";
in
{
  homebrew = {
    taps = [
      {
        name = "acsandmann/tap";
        trusted = true;
      }
    ];
    brews = [ "acsandmann/tap/rift" ];
  };

  agent = {
    serviceConfig = {
      Label = "git.acsandmann.rift";
      ProgramArguments = [
        "/bin/sh"
        "-lc"
        "/opt/homebrew/bin/rift"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
      EnvironmentVariables = {
        USER = profile.username;
        HOME = homeDir;
        PATH = "/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
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

    if [ -x /opt/homebrew/bin/rift-cli ] && /opt/homebrew/bin/rift-cli query metrics >/dev/null 2>&1; then
      $DRY_RUN_CMD /opt/homebrew/bin/rift-cli execute config reload >/dev/null 2>&1 \
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
    "rift/config.toml".source = ../../config/rift/config.toml;
    "rift/assign-windows" = {
      source = ../../config/rift/assign-windows;
      executable = true;
    };
    "rift/sketchybar-workspace-subscribe" = {
      source = ../../config/rift/sketchybar-workspace-subscribe;
      executable = true;
    };
    "rift/apply-horizontal-fullscreen" = {
      source = ../../config/rift/apply-horizontal-fullscreen;
      executable = true;
    };
  };
}
