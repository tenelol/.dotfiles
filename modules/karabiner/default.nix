{
  delib,
  hostTraits,
  hm,
  ...
}:
delib.scopedModule {
  name = "karabiner";
  scope = hostTraits.darwinDesktop;

  options = delib.singleEnableOption false;

  home.ifEnabled = {
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

    xdg.configFile."karabiner/karabiner.json" = {
      force = true;
      source = ./files/config/karabiner.json;
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
