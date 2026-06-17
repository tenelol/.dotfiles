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
  linuxConfig = builtins.readFile ../config/kanata/linux.kbd;
  darwinKanataPackage = pkgs.kanata-with-cmd;
  kanataBinPath = "/usr/local/bin/kanata";
in
delib.module {
  name = "kanata";

  options = delib.singleEnableOption isDesktop;

  darwin.ifDisabled = lib.mkIf isDarwinDesktop {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      uid="$(id -u ${profile.username})"

      /bin/launchctl bootout system/org.nixos.kanata >/dev/null 2>&1 || true
      /bin/launchctl bootout "gui/$uid/org.nixos.kanata" >/dev/null 2>&1 || true
      /usr/bin/pkill -f '/Applications/Kanata.app/Contents/MacOS/kanata' >/dev/null 2>&1 || true
      /usr/bin/pkill -f '${kanataBinPath}' >/dev/null 2>&1 || true
      /bin/rm -rf /Applications/Kanata.app
      kanata_link_target="$(/usr/bin/readlink ${kanataBinPath} 2>/dev/null || true)"
      if [ "$kanata_link_target" = "${darwinKanataPackage}/bin/kanata" ] || [ "$kanata_link_target" = "/run/current-system/sw/bin/kanata" ]; then
        /bin/rm -f ${kanataBinPath}
      fi
      /bin/rm -f /Library/PrivilegedHelperTools/local.nix-kanata-root
      /bin/rm -f /Library/LaunchDaemons/org.nixos.kanata.plist
      /bin/rm -f /Library/LaunchAgents/org.nixos.kanata.plist
    '';
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
        config = linuxConfig;
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
      darwinKanataPackage
    ];

    environment.etc."kanata/kanata.kbd".source = ../config/kanata/kanata.kbd;
    environment.etc."kanata/common.kbd".source = ../config/kanata/common.kbd;

    launchd.daemons.kanata = {
      serviceConfig = {
        ProgramArguments = [
          kanataBinPath
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
      uid="$(id -u ${profile.username})"

      # macOS Input Monitoring grants are tied to the launched binary. Keep this
      # path stable and add it to Privacy & Security > Input Monitoring once.
      if [ -e ${kanataBinPath} ] && [ ! -L ${kanataBinPath} ]; then
        echo "warning: ${kanataBinPath} exists and is not a symlink; leaving it unchanged" >&2
      else
        /usr/bin/install -d -m 0755 /usr/local/bin
        /bin/ln -sfn ${darwinKanataPackage}/bin/kanata ${kanataBinPath}
      fi

      if [ -e /Applications/Kanata.app ] && /usr/bin/grep -q 'local.nix-kanata' /Applications/Kanata.app/Contents/Info.plist 2>/dev/null; then
        /bin/rm -rf /Applications/Kanata.app
      fi

      /bin/rm -f /Library/PrivilegedHelperTools/local.nix-kanata-root

      for label in \
        org.nixos.start_karabiner_daemons \
        org.nixos.setsuid_karabiner_session_monitor; do
        /bin/launchctl bootout "system/$label" >/dev/null 2>&1 || true
      done
      /bin/rm -f \
        /Library/LaunchDaemons/org.nixos.start_karabiner_daemons.plist \
        /Library/LaunchDaemons/org.nixos.setsuid_karabiner_session_monitor.plist

      for label in \
        org.nixos.karabiner-elements \
        org.nixos.kanata \
        org.nixos.activate_karabiner_system_ext \
        org.pqrs.service.agent.Karabiner-Menu \
        org.pqrs.service.agent.Karabiner-Core-Service \
        org.pqrs.service.agent.Karabiner-Core-Service-rev2 \
        org.pqrs.service.agent.Karabiner-NotificationWindow \
        org.pqrs.service.agent.karabiner_console_user_server \
        org.pqrs.service.agent.karabiner_session_monitor; do
        /bin/launchctl bootout "gui/$uid/$label" >/dev/null 2>&1 || true
      done

      for label in \
        org.pqrs.karabiner.karabiner_grabber \
        org.pqrs.karabiner.karabiner_observer \
        org.pqrs.service.daemon.Karabiner-Core-Service; do
        /bin/launchctl bootout "system/$label" >/dev/null 2>&1 || true
      done

      /usr/bin/pkill -f '/Applications/.Nix-Karabiner/.Karabiner-VirtualHIDDevice-Manager.app' >/dev/null 2>&1 || true
      /usr/bin/pkill -f '/Applications/Karabiner-Elements.app/Contents/MacOS/Karabiner-Elements' >/dev/null 2>&1 || true
      /usr/bin/pkill -f '/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_' >/dev/null 2>&1 || true
      /usr/bin/pkill -f '/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-' >/dev/null 2>&1 || true

      /bin/rm -f "/Users/${profile.username}/Library/LaunchAgents/org.nixos.kanata.plist"
      # Clear launchd's stale crash/penalty state before starting Kanata.
      /bin/launchctl bootout system/org.nixos.kanata >/dev/null 2>&1 || true
      kanata_bootstrapped=0
      kanata_attempts=0
      while [ "$kanata_attempts" -lt 5 ]; do
        kanata_attempts=$((kanata_attempts + 1))
        if /bin/launchctl bootstrap system /Library/LaunchDaemons/org.nixos.kanata.plist >/dev/null 2>&1; then
          kanata_bootstrapped=1
          break
        fi
        /bin/sleep 0.2
      done
      if [ "$kanata_bootstrapped" = 1 ]; then
        /bin/launchctl kickstart -k system/org.nixos.kanata >/dev/null 2>&1 || true
      else
        echo "warning: failed to bootstrap org.nixos.kanata" >&2
      fi
    '';
  };
}
