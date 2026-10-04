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
    launchd.user.agents.boringnotch = {
      serviceConfig = {
        Label = "theboringteam.boringnotch";
        ProgramArguments = [
          "/usr/bin/open"
          "/Applications/boringNotch.app"
        ];
        RunAtLoad = true;
        KeepAlive = false;
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
