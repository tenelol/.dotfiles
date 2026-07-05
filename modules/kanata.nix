{
  delib,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
let
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
  isLinuxDesktop = !host.isServer && builtins.match ".*-linux" host.system != null;
  isDesktop = isDarwinDesktop || isLinuxDesktop;
  # Keep the Linux map aligned with the current macOS Kanata map. This gives a
  # Kinto-style macOS shortcut layer without running Kinto's mutable installer.
  macStyleConfig = builtins.readFile ../config/kanata/common.kbd;
  darwinKanata = import ../lib/darwin/kanata.nix { inherit pkgs profile; };
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
        config = macStyleConfig;
      };
    };
  };

  darwin.ifEnabled = lib.mkIf isDarwinDesktop {
    # Kanata uses the Karabiner VirtualHID driver on macOS, but the
    # Karabiner-Elements app itself should not manage key mappings.
    homebrew.casks = [
      "karabiner-elements"
    ];

    environment.systemPackages = [
      darwinKanata.package
    ];

    environment.etc."kanata/kanata.kbd".source = ../config/kanata/kanata.kbd;
    environment.etc."kanata/common.kbd".source = ../config/kanata/common.kbd;

    launchd.daemons.kanata = darwinKanata.daemon;

    system.activationScripts.postActivation.text = lib.mkAfter darwinKanata.enabledPostActivation;
  };
}
