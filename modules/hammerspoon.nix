{
  delib,
  hm,
  host,
  ...
}:
delib.module {
  name = "hammerspoon";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    homebrew.casks = [
      "hammerspoon"
    ];

    system.defaults.trackpad = {
      ForceSuppressed = false;
      TrackpadTwoFingerDoubleTapGesture = true;
    };

    launchd.user.agents.hammerspoon = {
      serviceConfig = {
        ProgramArguments = [
          "/usr/bin/open"
          "-gj"
          "-a"
          "Hammerspoon"
        ];
        RunAtLoad = true;
      };
    };
  };

  home.ifEnabled = {
    home.file.".hammerspoon/init.lua".source = ../config/hammerspoon/init.lua;

    home.activation.restartHammerspoon = hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -d /Applications/Hammerspoon.app ]; then
        /usr/bin/osascript -e 'tell application "Hammerspoon" to quit' >/dev/null 2>&1 || true
        /bin/sleep 0.5
        /usr/bin/open -gj -a Hammerspoon >/dev/null 2>&1 || true
      fi
    '';
  };
}
