{
  delib,
  hm,
  host,
  ...
}:
delib.module {
  name = "karabiner";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    homebrew.casks = [
      "karabiner-elements"
    ];

    launchd.user.agents.karabiner-elements = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-lc"
          ''
            if [ -d /Applications/Karabiner-Elements.app ]; then
              exec /usr/bin/open -gj -a Karabiner-Elements
            fi
          ''
        ];
        RunAtLoad = true;
      };
    };
  };

  home.ifEnabled = {
    xdg.configFile."karabiner/karabiner.json".source = ../config/karabiner/karabiner.json;

    home.activation.startKarabinerElements = hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -d /Applications/Karabiner-Elements.app ]; then
        /usr/bin/open -gj -a Karabiner-Elements >/dev/null 2>&1 || true
      fi
    '';
  };
}
