{
  delib,
  host,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "kanata";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    # Kanata uses the Karabiner VirtualHID driver on macOS. Keep the cask
    # installed, but leave key remapping itself to Kanata.
    homebrew.casks = [
      "karabiner-elements"
    ];

    environment.systemPackages = [
      pkgs.kanata
    ];

    environment.etc."kanata/kanata.kbd".source = ../config/kanata/kanata.kbd;

    launchd.daemons.kanata = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.kanata}/bin/kanata"
          "--cfg"
          "/etc/kanata/kanata.kbd"
          "--no-wait"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/var/log/kanata.log";
        StandardErrorPath = "/var/log/kanata.log";
      };
    };

    system.activationScripts.postActivation.text = lib.mkAfter ''
      /bin/launchctl kickstart -k system/org.nixos.kanata >/dev/null 2>&1 || true
    '';
  };
}
