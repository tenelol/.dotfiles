{
  delib,
  host,
  lib,
  pkgs,
  ...
}:
let
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
in
delib.module {
  name = "kanata";

  # Prefer native macOS handling for the function row; Kanata can intercept
  # media keys and, in failure modes, duplicate regular key input.
  options = delib.singleEnableOption false;

  darwin.ifDisabled = lib.mkIf isDarwinDesktop {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      /bin/launchctl bootout system/org.nixos.kanata >/dev/null 2>&1 || true
      /usr/bin/pkill -f '/Applications/Kanata.app/Contents/MacOS/kanata' >/dev/null 2>&1 || true
      /bin/rm -rf /Applications/Kanata.app
      /bin/rm -f /Library/LaunchDaemons/org.nixos.kanata.plist
    '';
  };

  darwin.ifEnabled = lib.mkIf isDarwinDesktop {
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
      if [ "$(/usr/bin/readlink /usr/local/bin/kanata 2>/dev/null || true)" = "/run/current-system/sw/bin/kanata" ]; then
        /bin/rm -f /usr/local/bin/kanata
      fi

      if [ -e /Applications/Kanata.app ] && ! /usr/bin/grep -q 'local.nix-kanata' /Applications/Kanata.app/Contents/Info.plist 2>/dev/null; then
        echo "warning: /Applications/Kanata.app exists and is not managed by this module; leaving it unchanged" >&2
      else
        /bin/rm -rf /Applications/Kanata.app
        /usr/bin/install -d -m 0755 /Applications/Kanata.app/Contents/MacOS
        /bin/cp /run/current-system/sw/bin/kanata /Applications/Kanata.app/Contents/MacOS/kanata
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
        <string>1</string>
      </dict>
      </plist>
      EOF
      fi

      for label in \
        org.nixos.start_karabiner_daemons \
        org.nixos.setsuid_karabiner_session_monitor; do
        /bin/launchctl bootout "system/$label" >/dev/null 2>&1 || true
      done

      /usr/bin/pkill -f '/Applications/.Nix-Karabiner/.Karabiner-VirtualHIDDevice-Manager.app' >/dev/null 2>&1 || true
      /bin/launchctl kickstart -k system/org.nixos.kanata >/dev/null 2>&1 || true
    '';
  };
}
