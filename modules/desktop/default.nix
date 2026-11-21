{
  delib,
  hostTraits,
  lib,
  profile,
  ...
}:
delib.module {
  name = "desktop";

  options =
    with delib;
    moduleOptions {
      darwin.windowManager = enumOption [ "native" "rift" "aerospace" "omniwm" ] (
        if hostTraits.darwinDesktop then "rift" else "native"
      );
      linux.windowManager = enumOption [ "none" "niri" "hyprland" ] (
        if hostTraits.linuxDesktop then "niri" else "none"
      );
    };

  myconfig.always = { cfg, ... }: {
    args.shared.desktopSelection = {
      rift = hostTraits.darwinDesktop && cfg.darwin.windowManager == "rift";
      aerospace = hostTraits.darwinDesktop && cfg.darwin.windowManager == "aerospace";
      autoraise = hostTraits.darwinDesktop && cfg.darwin.windowManager == "aerospace";
      omniwm = hostTraits.darwinDesktop && cfg.darwin.windowManager == "omniwm";
      niri = hostTraits.linuxDesktop && cfg.linux.windowManager == "niri";
      hyprland = hostTraits.linuxDesktop && cfg.linux.windowManager == "hyprland";
    };
    # Each macOS window manager stops itself from `darwin.ifDisabled` so a
    # rice switch hands over without one module knowing the others. Apps
    # started with `open` outlive bootout, hence the pkill.
    args.shared.stopDarwinWindowManager =
      { labels, processes }:
      lib.mkAfter ''
        uid="$(/usr/bin/id -u ${profile.username})"
        for label in ${lib.escapeShellArgs labels}; do
          /bin/launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true
        done
        for process in ${lib.escapeShellArgs processes}; do
          /usr/bin/pkill -u ${profile.username} -x "$process" >/dev/null 2>&1 || true
        done
      '';
  };
}
