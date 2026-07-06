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
  };

  home.ifEnabled = lib.mkIf isDarwinDesktop {
    launchd.agents.karabiner-elements = {
      enable = true;
      config = {
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

    home.file.".local/bin/toggle-ghostty-quick-terminal" = {
      source = ../config/scripts/toggle-ghostty-quick-terminal;
      executable = true;
    };

    xdg.configFile."karabiner/karabiner.json" = {
      force = true;
      source = ../config/karabiner/karabiner.json;
    };

    home.activation.reloadKarabiner = hm.dag.entryAfter [ "setupLaunchAgents" ] ''
      user_id=$(/usr/bin/id -u)
      $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$user_id/org.nix-community.home.karabiner-elements" >/dev/null 2>&1 || true

      if [ -d /Applications/Karabiner-Elements.app ]; then
        $DRY_RUN_CMD /usr/bin/open -gj -a Karabiner-Elements >/dev/null 2>&1 || true
      fi

      if [ -x /opt/homebrew/bin/karabiner_cli ]; then
        $DRY_RUN_CMD /bin/sleep 0.5
        $DRY_RUN_CMD /opt/homebrew/bin/karabiner_cli --select-profile 'Default profile' >/dev/null 2>&1 || true
      fi
    '';
  };
}
