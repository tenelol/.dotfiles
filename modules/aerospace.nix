{
  delib,
  hm,
  host,
  lib,
  profile,
  ...
}:
let
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
  aerospace = import ../lib/darwin/aerospace.nix { inherit profile; };
in
delib.module {
  name = "aerospace";

  options = delib.singleEnableOption false;

  darwin.always = lib.mkIf isDarwinDesktop {
    homebrew = aerospace.homebrew;
  };

  darwin.ifEnabled = lib.mkIf isDarwinDesktop {
    launchd.user.agents.aerospace = aerospace.agent;
    system.activationScripts.stopRiftForAerospace.text = aerospace.stopRift;
  };

  home.ifEnabled = lib.mkIf isDarwinDesktop {
    xdg.configFile = aerospace.configFiles;

    home.activation.prepareAerospaceApp = hm.dag.entryAfter [ "linkGeneration" ] aerospace.prepareApp;

    home.activation.assignAerospaceWindows = hm.dag.entryAfter [
      "prepareAerospaceApp"
    ] aerospace.assignWindows;

    home.activation.refreshAerospaceSketchybar = hm.dag.entryAfter [
      "assignAerospaceWindows"
    ] aerospace.refreshSketchybar;
  };
}
