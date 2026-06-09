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
  darwinKanataVersion = lib.getVersion darwinKanataPackage;
in
delib.module {
  name = "kanata";

  options = delib.singleEnableOption isDesktop;

  darwin.ifDisabled = lib.mkIf isDarwinDesktop {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      /bin/launchctl bootout system/org.nixos.kanata >/dev/null 2>&1 || true
      /usr/bin/pkill -f '/Applications/Kanata.app/Contents/MacOS/kanata' >/dev/null 2>&1 || true
      /bin/rm -rf /Applications/Kanata.app
      /bin/rm -f /Library/LaunchDaemons/org.nixos.kanata.plist
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
          "/Applications/Kanata.app/Contents/MacOS/kanata"
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

      kanata_link_target="$(/usr/bin/readlink /usr/local/bin/kanata 2>/dev/null || true)"
      if [ "$kanata_link_target" = "/run/current-system/sw/bin/kanata" ] || [ "$kanata_link_target" = "${darwinKanataPackage}/bin/kanata" ]; then
        /bin/rm -f /usr/local/bin/kanata
      fi

      kanata_app_needs_install=false
      if [ ! -x /Applications/Kanata.app/Contents/MacOS/kanata ]; then
        kanata_app_needs_install=true
      elif ! /usr/bin/grep -q 'local.nix-kanata' /Applications/Kanata.app/Contents/Info.plist 2>/dev/null; then
        kanata_app_needs_install=true
      elif ! /usr/bin/grep -q '<string>${darwinKanataVersion}</string>' /Applications/Kanata.app/Contents/Info.plist 2>/dev/null; then
        kanata_app_needs_install=true
      elif [ "$(/usr/bin/codesign -dv /Applications/Kanata.app 2>&1 | /usr/bin/sed -n 's/^Identifier=//p')" != "local.nix-kanata" ]; then
        kanata_app_needs_install=true
      fi

      if [ -e /Applications/Kanata.app ] && ! /usr/bin/grep -q 'local.nix-kanata' /Applications/Kanata.app/Contents/Info.plist 2>/dev/null; then
        echo "warning: /Applications/Kanata.app exists and is not managed by this module; leaving it unchanged" >&2
      elif [ "$kanata_app_needs_install" = true ]; then
        /bin/rm -rf /Applications/Kanata.app
        /usr/bin/install -d -m 0755 /Applications/Kanata.app/Contents/MacOS
        /bin/cp ${darwinKanataPackage}/bin/kanata /Applications/Kanata.app/Contents/MacOS/kanata
        /bin/chmod 0755 /Applications/Kanata.app/Contents/MacOS/kanata
        /bin/chmod 0755 /Applications/Kanata.app/Contents/MacOS
        /bin/cat > /Applications/Kanata.app/Contents/Info.plist <<'EOF'
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleDisplayName</key>
        <string>Kanata</string>
        <key>CFBundleExecutable</key>
        <string>kanata</string>
        <key>CFBundleIdentifier</key>
        <string>local.nix-kanata</string>
        <key>CFBundleName</key>
        <string>Kanata</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleVersion</key>
        <string>${darwinKanataVersion}</string>
      </dict>
      </plist>
      EOF
        /usr/bin/codesign --force --deep --sign - --identifier local.nix-kanata /Applications/Kanata.app
      fi

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

      kanata_tcc_count="$(
        {
          /usr/bin/sqlite3 "/Users/${profile.username}/Library/Application Support/com.apple.TCC/TCC.db" \
            "select count(*) from access where service = 'kTCCServiceListenEvent' and (client like '%Kanata%' or client like '%kanata%' or client like '%local.nix-kanata%');" || true
          /usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
            "select count(*) from access where service = 'kTCCServiceListenEvent' and (client like '%Kanata%' or client like '%kanata%' or client like '%local.nix-kanata%');" || true
        } 2>/dev/null | /usr/bin/awk '{total += $1} END {print total + 0}'
      )"
      if [ "$kanata_tcc_count" = 0 ]; then
        echo "warning: Kanata has no Input Monitoring permission; enable /Applications/Kanata.app in System Settings > Privacy & Security > Input Monitoring" >&2
      fi

      /bin/launchctl kickstart -k system/org.nixos.kanata >/dev/null 2>&1 || true
    '';
  };
}
