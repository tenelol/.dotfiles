{ profile }:
let
  homeDir = "/Users/${profile.username}";
  path = "/opt/homebrew/bin:/opt/homebrew/sbin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
in
{
  homebrew = {
    taps = [
      {
        name = "nikitabobko/tap";
        trusted = true;
      }
    ];
    casks = [ "nikitabobko/tap/aerospace" ];
  };

  agent = {
    serviceConfig = {
      ProgramArguments = [
        "/usr/bin/open"
        "-g"
        "--env"
        "HOME=${homeDir}"
        "--env"
        "XDG_CONFIG_HOME=${homeDir}/.config"
        "--env"
        "PATH=${path}"
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
        PATH = path;
      };
    };

    managedBy = "aerospace";
  };

  stopRift = ''
    uid="$(/usr/bin/id -u ${profile.username})"

    for label in git.acsandmann.rift org.nixos.rift homebrew.mxcl.rift; do
      /bin/launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true
    done

    /usr/bin/pkill -u ${profile.username} -x rift >/dev/null 2>&1 || true
  '';

  prepareApp = ''
    if [ ! -d /Applications/AeroSpace.app ] && [ -x /opt/homebrew/bin/brew ]; then
      $DRY_RUN_CMD /usr/bin/env HOMEBREW_NO_AUTO_UPDATE=1 /opt/homebrew/bin/brew reinstall --cask aerospace >/dev/null 2>&1 || true
    fi

    if [ -d /Applications/AeroSpace.app ]; then
      $DRY_RUN_CMD /usr/bin/xattr -dr com.apple.quarantine /Applications/AeroSpace.app >/dev/null 2>&1 || true
      $DRY_RUN_CMD /usr/bin/open -g \
        --env HOME=${homeDir} \
        --env XDG_CONFIG_HOME=${homeDir}/.config \
        --env PATH=${path} \
        /Applications/AeroSpace.app \
        --args --config-path ${homeDir}/.config/aerospace/aerospace.toml >/dev/null 2>&1 || true
    fi

    if [ -x /opt/homebrew/bin/aerospace ]; then
      $DRY_RUN_CMD /opt/homebrew/bin/aerospace reload-config --no-gui >/dev/null 2>&1 || true
    fi
  '';

  assignWindows = ''
    if [ -x ${homeDir}/.config/aerospace/assign-windows ]; then
      $DRY_RUN_CMD ${homeDir}/.config/aerospace/assign-windows >/dev/null 2>&1 || true
    fi
  '';

  refreshSketchybar = ''
    if [ -x /opt/homebrew/bin/sketchybar ]; then
      $DRY_RUN_CMD /opt/homebrew/bin/sketchybar --trigger workspace_change REFRESH=all >/dev/null 2>&1 || true
    fi
  '';

  configFiles = {
    "aerospace/aerospace.toml".source = ../../config/aerospace/aerospace.toml;
    "aerospace/workspace-local" = {
      source = ../../config/aerospace/workspace-local;
      executable = true;
    };
    "aerospace/assign-windows" = {
      source = ../../config/aerospace/assign-windows;
      executable = true;
    };
  };
}
