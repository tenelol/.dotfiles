{ pkgs, profile }:
let
  package = pkgs.kanata-with-cmd;
  binPath = "/usr/local/bin/kanata";
in
{
  inherit binPath package;

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
    kanata_link_target="$(/usr/bin/readlink ${binPath} 2>/dev/null || true)"
    if [ "$kanata_link_target" = "${package}/bin/kanata" ] || [ "$kanata_link_target" = "/run/current-system/sw/bin/kanata" ]; then
      /bin/rm -f ${binPath}
    fi
    /bin/rm -f /Library/PrivilegedHelperTools/local.nix-kanata-root
    /bin/rm -f /Library/LaunchDaemons/org.nixos.kanata.plist
    /bin/rm -f /Library/LaunchAgents/org.nixos.kanata.plist
  '';

  enabledPostActivation = ''
    uid="$(id -u ${profile.username})"

    # Kanata uses the Karabiner VirtualHID driver on macOS. Keep the launched
    # binary path stable so the Input Monitoring grant survives rebuilds.
    if [ -e ${binPath} ] && [ ! -L ${binPath} ]; then
      echo "warning: ${binPath} exists and is not a symlink; leaving it unchanged" >&2
    else
      /usr/bin/install -d -m 0755 /usr/local/bin
      /bin/ln -sfn ${package}/bin/kanata ${binPath}
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
}
