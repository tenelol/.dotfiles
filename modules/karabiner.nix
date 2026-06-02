{
  delib,
  hm,
  host,
  lib,
  ...
}:
let
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
in
delib.module {
  name = "karabiner";

  options = delib.singleEnableOption false;

  darwin.ifEnabled = lib.mkIf isDarwinDesktop {
    homebrew.casks = [
      "karabiner-elements"
    ];

    launchd.user.agents.karabiner-elements = {
      serviceConfig = {
        ProgramArguments = [
          "/usr/bin/open"
          "-gj"
          "-a"
          "Karabiner-Elements"
        ];
        RunAtLoad = true;
        ProcessType = "Interactive";
      };
    };
  };

  home.ifEnabled = lib.mkIf isDarwinDesktop {
    xdg.configFile."karabiner/karabiner.json" = {
      force = true;
      source = ../config/karabiner/karabiner.json;
    };

    home.activation.reloadKarabiner = hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -d /Applications/Karabiner-Elements.app ]; then
        $DRY_RUN_CMD /usr/bin/open -gj -a Karabiner-Elements >/dev/null 2>&1 || true
      fi

      if [ -x /opt/homebrew/bin/karabiner_cli ]; then
        $DRY_RUN_CMD /opt/homebrew/bin/karabiner_cli --select-profile 'Default profile' >/dev/null 2>&1 || true
      fi
    '';
  };
}
