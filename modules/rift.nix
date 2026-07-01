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
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
  rift = import ../lib/darwin/rift.nix { inherit pkgs profile; };
in
delib.module {
  name = "rift";

  options = delib.singleEnableOption isDarwinDesktop;

  darwin.always = lib.mkIf isDarwinDesktop {
    homebrew = rift.homebrew;
  };

  darwin.ifEnabled = {
    launchd.user.agents.rift = rift.agent;
    system.activationScripts.cleanupLegacyYabai.text = rift.cleanupLegacyYabai;
  };

  home.ifEnabled = lib.mkIf isDarwinDesktop {
    home.activation.cleanupLegacyYabaiConfig = hm.dag.entryBefore [
      "checkLinkTargets"
    ] rift.cleanupLegacyYabaiConfig;

    home.activation.syncRiftSketchybarSubscription = hm.dag.entryAfter [
      "linkGeneration"
    ] rift.syncSketchybarSubscription;

    xdg.configFile = rift.configFiles;
  };
}
