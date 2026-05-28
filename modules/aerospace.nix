{
  delib,
  hm,
  host,
  lib,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
in
delib.module {
  name = "aerospace";

  options = delib.singleEnableOption false;

  darwin.always = lib.mkIf isDarwinDesktop {
    homebrew = {
      taps = [ "nikitabobko/tap" ];
      casks = [ "nikitabobko/tap/aerospace" ];
    };
  };

  darwin.ifEnabled = lib.mkIf isDarwinDesktop {
    launchd.user.agents.aerospace = {
      serviceConfig = {
        ProgramArguments = [
          "/usr/bin/open"
          "-g"
          "--env"
          "HOME=${homeDir}"
          "--env"
          "XDG_CONFIG_HOME=${homeDir}/.config"
          "--env"
          "PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"
          "/Applications/AeroSpace.app"
          "--args"
          "--config-path"
          "${homeDir}/.config/aerospace/aerospace.toml"
        ];
        RunAtLoad = true;
        ProcessType = "Interactive";
        EnvironmentVariables = {
          USER = profile.username;
          HOME = homeDir;
          XDG_CONFIG_HOME = "${homeDir}/.config";
          PATH = "/opt/homebrew/bin:/opt/homebrew/sbin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
      };

      managedBy = "aerospace";
    };

    # Disable "Displays have separate Spaces" for AeroSpace. Separate macOS
    # Spaces can make same-app windows on different monitors raise together.
    system.defaults.spaces.spans-displays = lib.mkForce true;

    system.activationScripts.stopRiftForAerospace.text = ''
      uid="$(/usr/bin/id -u ${profile.username})"

      for label in git.acsandmann.rift org.nixos.rift homebrew.mxcl.rift; do
        /bin/launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true
      done

      /usr/bin/pkill -u ${profile.username} -x rift >/dev/null 2>&1 || true
    '';
  };

  home.ifEnabled = lib.mkIf isDarwinDesktop {
    xdg.configFile."aerospace/aerospace.toml".source = ../config/aerospace/aerospace.toml;
    xdg.configFile."aerospace/workspace-local" = {
      source = ../config/aerospace/workspace-local;
      executable = true;
    };
    xdg.configFile."aerospace/assign-windows" = {
      source = ../config/aerospace/assign-windows;
      executable = true;
    };

    home.activation.prepareAerospaceApp = hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ ! -d /Applications/AeroSpace.app ] && [ -x /opt/homebrew/bin/brew ]; then
        $DRY_RUN_CMD /usr/bin/env HOMEBREW_NO_AUTO_UPDATE=1 /opt/homebrew/bin/brew reinstall --cask aerospace >/dev/null 2>&1 || true
      fi

      if [ -d /Applications/AeroSpace.app ]; then
        $DRY_RUN_CMD /usr/bin/xattr -dr com.apple.quarantine /Applications/AeroSpace.app >/dev/null 2>&1 || true
        $DRY_RUN_CMD /usr/bin/open -g \
          --env HOME=${homeDir} \
          --env XDG_CONFIG_HOME=${homeDir}/.config \
          --env PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin \
          /Applications/AeroSpace.app \
          --args --config-path ${homeDir}/.config/aerospace/aerospace.toml >/dev/null 2>&1 || true
      fi

      if [ -x /opt/homebrew/bin/aerospace ]; then
        $DRY_RUN_CMD /opt/homebrew/bin/aerospace reload-config --no-gui >/dev/null 2>&1 || true
      fi
    '';

    home.activation.assignAerospaceWindows = hm.dag.entryAfter [ "prepareAerospaceApp" ] ''
      if [ -x ${homeDir}/.config/aerospace/assign-windows ]; then
        $DRY_RUN_CMD ${homeDir}/.config/aerospace/assign-windows >/dev/null 2>&1 || true
      fi
    '';

    home.activation.refreshAerospaceSketchybar = hm.dag.entryAfter [ "assignAerospaceWindows" ] ''
      if [ -x /opt/homebrew/bin/sketchybar ]; then
        $DRY_RUN_CMD /opt/homebrew/bin/sketchybar --trigger workspace_change REFRESH=all >/dev/null 2>&1 || true
      fi
    '';
  };
}
