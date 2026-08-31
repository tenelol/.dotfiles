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
  linuxMacConfig = builtins.readFile ./kanata/files/linux-mac.kbd;
  # macOS Input Monitoring follows the executable's code identity. Keep using
  # Kanata's official cmd-allowed binary instead of rebuilding it from nixpkgs.
  darwinKanataPackage = pkgs.callPackage ../packages/kanata-with-cmd.nix { };
  packageBin = "${darwinKanataPackage}/bin/kanata";
  binPath = "/usr/local/bin/kanata";
  managedMarker = "/usr/local/bin/.kanata-managed-by-nix-darwin";
  checkManagedPath = ''
    kanata_managed=0
    if [ -e ${managedMarker} ]; then
      kanata_managed=1
    elif [ -L ${binPath} ]; then
      case "$(/usr/bin/readlink ${binPath})" in
        ${packageBin}|/run/current-system/sw/bin/kanata|/nix/store/*-kanata-*/bin/kanata)
          kanata_managed=1
          ;;
      esac
    fi
  '';

  daemon = {
    serviceConfig = {
      ProgramArguments = [
        binPath
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

  disabledPostActivation = ''
    uid="$(id -u ${profile.username})"

    /bin/launchctl bootout system/org.nixos.kanata >/dev/null 2>&1 || true
    /bin/launchctl bootout "gui/$uid/org.nixos.kanata" >/dev/null 2>&1 || true
    /usr/bin/pkill -f '/Applications/Kanata.app/Contents/MacOS/kanata' >/dev/null 2>&1 || true
    /usr/bin/pkill -f '${binPath}' >/dev/null 2>&1 || true
    /bin/rm -rf /Applications/Kanata.app
    ${checkManagedPath}
    if [ "$kanata_managed" = 1 ]; then
      /bin/rm -f ${binPath}
      /bin/rm -f ${managedMarker}
    fi
    /bin/rm -f /Library/PrivilegedHelperTools/local.nix-kanata-root
    /bin/rm -f /Library/LaunchDaemons/org.nixos.kanata.plist
    /bin/rm -f /Library/LaunchAgents/org.nixos.kanata.plist
  '';

  enabledPostActivation = ''
    uid="$(id -u ${profile.username})"

    # Keep the Input Monitoring path stable while sourcing the binary from the
    # immutable Nix store.
    ${checkManagedPath}
    if [ -e ${binPath} ] || [ -L ${binPath} ]; then
      if [ "$kanata_managed" = 1 ]; then
        /bin/rm -f ${binPath}
      else
        echo "error: refusing to replace unmanaged ${binPath}" >&2
        exit 1
      fi
    fi
    /usr/bin/install -d -o root -g wheel -m 0755 /usr/local/bin
    kanata_tmp="${binPath}.nix-darwin.$$"
    /usr/bin/install -o root -g wheel -m 0755 ${packageBin} "$kanata_tmp"
    /bin/mv -f "$kanata_tmp" ${binPath}
    /usr/bin/install -o root -g wheel -m 0644 /dev/null ${managedMarker}

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
in
delib.module {
  name = "kanata";

  options = delib.singleEnableOption isDesktop;

  darwin.ifDisabled = lib.mkIf isDarwinDesktop {
    system.activationScripts.postActivation.text = lib.mkAfter disabledPostActivation;
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
    environment.systemPackages = [ darwinKanataPackage ];

    environment.etc."kanata/kanata.kbd".source = ./kanata/files/kanata.kbd;
    environment.etc."kanata/common.kbd".source = ./kanata/files/common.kbd;

    launchd.daemons.kanata = daemon;

    system.activationScripts.postActivation.text = lib.mkAfter enabledPostActivation;
  };
}
