{
  delib,
  hostTraits,
  lib,
  profile,
  ...
}:
delib.module {
  name = "boringnotch";

  options = delib.singleEnableOption hostTraits.darwinDesktop;

  darwin.ifEnabled = {
    launchd.user.agents.boringnotch = {
      serviceConfig = {
        Label = "theboringteam.boringnotch";
        # Run the binary itself so launchd supervises it; /usr/bin/open exits at
        # once and left nothing to restart. Like OmniWM, relaunch only on crashes.
        ProgramArguments = [ "/Applications/boringNotch.app/Contents/MacOS/boringNotch" ];
        RunAtLoad = true;
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        ProcessType = "Interactive";
      };

      managedBy = "boringnotch";
    };

    # Start after the installer has placed the user-owned app copy.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      uid="$(id -u ${profile.username})"

      if [ -d "/Applications/boringNotch.app" ]; then
        launchctl asuser "$uid" sudo --user=${profile.username} \
          /bin/launchctl kickstart -k "gui/$uid/theboringteam.boringnotch" \
          >/dev/null 2>&1 || true
      fi
    '';
  };
}
