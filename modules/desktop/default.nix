{ delib, hostTraits, ... }:
delib.module {
  name = "desktop";

  options =
    with delib;
    moduleOptions {
      darwin.windowManager = enumOption [ "native" "rift" "aerospace" ] (
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
      niri = hostTraits.linuxDesktop && cfg.linux.windowManager == "niri";
      hyprland = hostTraits.linuxDesktop && cfg.linux.windowManager == "hyprland";
    };
  };
}
