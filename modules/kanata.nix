{
  delib,
  host,
  lib,
  profile,
  ...
}:
let
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
  isLinuxDesktop = !host.isServer && builtins.match ".*-linux" host.system != null;
  isDesktop = isDarwinDesktop || isLinuxDesktop;
  # Give Linux apps a macOS-style Command layer without running Kinto's mutable
  # installer. macOS still uses common.kbd unchanged.
  linuxMacConfig = builtins.readFile ../config/kanata/linux-mac.kbd;
  darwinKanata = import ../lib/darwin/kanata.nix { inherit profile; };
in
delib.module {
  name = "kanata";

  options = delib.singleEnableOption isDesktop;

  darwin.ifDisabled = lib.mkIf isDarwinDesktop {
    system.activationScripts.postActivation.text = lib.mkAfter darwinKanata.disabledPostActivation;
  };

  nixos.ifDisabled = lib.mkIf isLinuxDesktop {
    services.kanata.enable = false;
  };

  nixos.ifEnabled = lib.mkIf isLinuxDesktop {
    services.keyd.enable = lib.mkForce false;

    services.kanata = {
      enable = true;
      keyboards.default = {
        extraDefCfg = "process-unmapped-keys yes";
        config = linuxMacConfig;
      };
    };
  };

  darwin.ifEnabled = lib.mkIf isDarwinDesktop {
    # Kanata uses the Homebrew-managed Karabiner VirtualHID driver, but the
    # Karabiner-Elements app itself should not manage key mappings.
    homebrew = {
      taps = [
        {
          name = "tener/dotfiles";
          clone_target = "file:///Users/${profile.username}/.dotfiles";
          force_auto_update = true;
          trusted = true;
        }
      ];
      brews = [ "tener/dotfiles/kanata-with-cmd" ];
    };

    environment.etc."kanata/kanata.kbd".source = ../config/kanata/kanata.kbd;
    environment.etc."kanata/common.kbd".source = ../config/kanata/common.kbd;

    launchd.daemons.kanata = darwinKanata.daemon;

    system.activationScripts.postActivation.text = lib.mkAfter darwinKanata.enabledPostActivation;
  };
}
