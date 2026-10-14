{
  delib,
  desktopSelection,
  hostTraits,
  lib,
  pkgs,
  profile,
  ...
}:
delib.scopedModule {
  name = "omniwm";
  scope = hostTraits.darwinDesktop;

  options = delib.moduleOptions {
    enable = delib.readOnly (delib.boolOption desktopSelection.omniwm);
  };

  darwin.ifEnabled.system.activationScripts.preActivation.text = lib.mkAfter ''
    uid="$(/usr/bin/id -u ${profile.username})"

    for label in git.acsandmann.rift org.nixos.rift homebrew.mxcl.rift org.nixos.aerospace org.nixos.autoraise; do
      /bin/launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true
    done
    for process in rift Rift AeroSpace aerospace AutoRaise autoraise; do
      /usr/bin/pkill -u ${profile.username} -x "$process" >/dev/null 2>&1 || true
    done
  '';

  darwin.ifDisabled.system.activationScripts.preActivation.text = lib.mkAfter ''
    uid="$(/usr/bin/id -u ${profile.username})"

    /bin/launchctl bootout "gui/$uid/org.nix-community.home.omniwm" >/dev/null 2>&1 || true
    /usr/bin/pkill -u ${profile.username} -x OmniWM >/dev/null 2>&1 || true
  '';

  home.ifEnabled.programs.omniwm = {
    enable = true;
    package = pkgs.callPackage ../../packages/omniwm.nix { };
  };
}
