{
  delib,
  hm,
  host,
  pkgs,
  ...
}:
delib.module {
  name = "sketchybar";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    homebrew = {
      taps = [
        {
          name = "FelixKratz/formulae";
          trusted = true;
        }
      ];
      brews = [ "FelixKratz/formulae/sketchybar" ];
    };

    launchd.user.agents.sketchybar = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-lc"
          "/opt/homebrew/bin/sketchybar"
        ];
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
      };

      managedBy = "sketchybar";
    };
  };

  home.ifEnabled = {
    home.activation.cleanupLegacySketchybarDir = hm.dag.entryBefore [ "checkLinkTargets" ] ''
      legacy_sketchybar="$HOME/.config/sketchybar"

      if [ -L "$legacy_sketchybar" ]; then
        target="$(${pkgs.coreutils}/bin/readlink "$legacy_sketchybar")"

        case "$target" in
          /nix/store/*-home-manager-files/.config/sketchybar)
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$legacy_sketchybar"
            ;;
        esac
      fi
    '';

    xdg.configFile."sketchybar".source = ../config/sketchybar;

    home.activation.restartSketchybar = hm.dag.entryAfter [ "linkGeneration" ] ''
      uid="$(/usr/bin/id -u)"

      if [ -x /opt/homebrew/bin/sketchybar ]; then
        $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$uid/org.nixos.sketchybar" >/dev/null 2>&1 || true
      fi
    '';
  };
}
