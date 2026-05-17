{
  delib,
  hm,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
in
delib.module {
  name = "rift";

  options = delib.singleEnableOption isDarwinDesktop;

  darwin.always = lib.mkIf isDarwinDesktop {
    homebrew = {
      taps = [ "acsandmann/tap" ];
      brews = [ "acsandmann/tap/rift" ];
    };
  };

  darwin.ifEnabled = {
    launchd.user.agents.rift = {
      serviceConfig = {
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

    system.activationScripts.cleanupLegacyYabai.text = ''
      uid="$(/usr/bin/id -u ${profile.username})"

      for label in org.nixos.aerospace org.nixos.autoraise org.nixos.yabai org.nixos.skhd homebrew.mxcl.yabai homebrew.mxcl.skhd; do
        /bin/launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true
      done

      if /usr/bin/pgrep -u ${profile.username} -x AeroSpace >/dev/null 2>&1; then
        launchctl asuser "$uid" sudo --user=${profile.username} /usr/bin/osascript \
          -e 'tell application "AeroSpace" to quit' >/dev/null 2>&1 || true
      fi

      /usr/bin/pkill -u ${profile.username} -x AeroSpace >/dev/null 2>&1 || true
      /usr/bin/pkill -u ${profile.username} -x aerospace >/dev/null 2>&1 || true
      /usr/bin/pkill -u ${profile.username} -x autoraise >/dev/null 2>&1 || true
      /usr/bin/pkill -u ${profile.username} -x AutoRaise >/dev/null 2>&1 || true
      /usr/bin/pkill -u ${profile.username} -x yabai >/dev/null 2>&1 || true
      /usr/bin/pkill -u ${profile.username} -x skhd >/dev/null 2>&1 || true

      for plist in \
        /Library/LaunchAgents/org.nixos.yabai.plist \
        /Library/LaunchAgents/org.nixos.skhd.plist \
        "${homeDir}/Library/LaunchAgents/org.nixos.yabai.plist" \
        "${homeDir}/Library/LaunchAgents/org.nixos.skhd.plist" \
        "${homeDir}/Library/LaunchAgents/homebrew.mxcl.yabai.plist" \
        "${homeDir}/Library/LaunchAgents/homebrew.mxcl.skhd.plist"; do
        /bin/rm -f "$plist"
      done
    '';
  };

  home.ifEnabled = {
    home.activation.cleanupLegacyYabaiConfig = hm.dag.entryBefore [ "checkLinkTargets" ] ''
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

    home.activation.syncRiftSketchybarSubscription = hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -x "$HOME/.config/rift/sketchybar-workspace-subscribe" ]; then
        $DRY_RUN_CMD "$HOME/.config/rift/sketchybar-workspace-subscribe" >/dev/null 2>&1 || true
      fi
    '';

    xdg.configFile."rift/config.toml".source = ../config/rift/config.toml;
    xdg.configFile."rift/sketchybar-workspace-subscribe" = {
      source = ../config/rift/sketchybar-workspace-subscribe;
      executable = true;
    };
  };
}
