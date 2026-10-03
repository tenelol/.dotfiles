{
  delib,
  pkgs,
  desktopSelection,
  hostTraits,
  hm,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
  path = "/run/current-system/sw/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";

  package = pkgs.aerospace;
  appPath = "/Applications/Nix Apps/AeroSpace.app";

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
        appPath
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
    if [ -d "${appPath}" ]; then
      $DRY_RUN_CMD /usr/bin/open -g \
        --env HOME=${homeDir} \
        --env XDG_CONFIG_HOME=${homeDir}/.config \
        --env PATH=${path} \
        "${appPath}" --args --config-path ${homeDir}/.config/aerospace/aerospace.toml >/dev/null 2>&1 || true
    fi
    $DRY_RUN_CMD ${package}/bin/aerospace reload-config --no-gui >/dev/null 2>&1 || true
  '';

  assignWindows = ''
    if [ -x ${homeDir}/.config/aerospace/assign-windows ]; then
      $DRY_RUN_CMD ${homeDir}/.config/aerospace/assign-windows >/dev/null 2>&1 || true
    fi
  '';

  refreshSketchybar = ''
    if [ -x /run/current-system/sw/bin/sketchybar ]; then
      $DRY_RUN_CMD /run/current-system/sw/bin/sketchybar --trigger workspace_change REFRESH=all >/dev/null 2>&1 || true
    fi
  '';

  configFiles = {
    "aerospace/aerospace.toml".source = ./files/aerospace.toml;
    "aerospace/workspace-local" = {
      source = ./files/workspace-local;
      executable = true;
    };
    "aerospace/assign-windows" = {
      source = ./files/assign-windows;
      executable = true;
    };
  };
in
delib.scopedModule {
  name = "aerospace";
  scope = hostTraits.darwinDesktop;

  options = delib.moduleOptions {
    enable = delib.readOnly (delib.boolOption desktopSelection.aerospace);
  };

  darwin.always.environment.systemPackages = [ package ];

  darwin.ifEnabled = {
    launchd.user.agents.aerospace = agent;
    system.activationScripts.stopRiftForAerospace.text = stopRift;
  };

  home.ifEnabled = {
    xdg.configFile = configFiles;

    home.activation.prepareAerospaceApp = hm.dag.entryAfter [ "linkGeneration" ] prepareApp;

    home.activation.assignAerospaceWindows = hm.dag.entryAfter [
      "prepareAerospaceApp"
    ] assignWindows;

    home.activation.refreshAerospaceSketchybar = hm.dag.entryAfter [
      "assignAerospaceWindows"
    ] refreshSketchybar;
  };
}
