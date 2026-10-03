{
  delib,
  pkgs,
  host,
  lib,
  profile,
  ...
}:
delib.module {
  name = "boringnotch";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    environment.systemPackages = [ (pkgs.callPackage ../../packages/boringnotch.nix { }) ];

    launchd.user.agents.boringnotch = {
      serviceConfig = {
        Label = "theboringteam.boringnotch";
        ProgramArguments = [
          "/usr/bin/open"
          "/Applications/Nix Apps/boringNotch.app"
        ];
        RunAtLoad = true;
        KeepAlive = false;
        ProcessType = "Interactive";
      };

      managedBy = "boringnotch";
    };

    # Nix app links may be installed after launchd setup, so kickstart once after
    # activation to make a fresh install start without waiting for the next login.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      uid="$(id -u ${profile.username})"

      if [ -d /Applications/Nix Apps/boringNotch.app ]; then
        launchctl asuser "$uid" sudo --user=${profile.username} \
          /bin/launchctl kickstart -k "gui/$uid/theboringteam.boringnotch" \
          >/dev/null 2>&1 || true
      fi
    '';
  };
}
