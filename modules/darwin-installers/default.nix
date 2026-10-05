{
  delib,
  host,
  hostTraits,
  lib,
  pkgs,
  profile,
  config,
  hm,
  ...
}:
let
  extract = pkgs.callPackage ../../packages/macos-installer-source.nix { };
  casks = pkgs.brewCasks;
  gui = pkgs.callPackage ../../packages/macos-apps.nix { } {
    owner = profile.username;
    fullDesktop = host.fullDesktopFeatured;
    boringNotchEnabled = config.myconfig.boringnotch.enable;
  };
  installHash = pkgs.callPackage ../../packages/firefox-install-hash.nix { };
  versionPrefix = version: lib.concatStringsSep "." (lib.take 2 (lib.splitString "." version)) + ".";
  karabinerDmg = pkgs.fetchurl {
    url = "https://github.com/pqrs-org/Karabiner-Elements/releases/download/v16.0.0/Karabiner-Elements-16.0.0.dmg";
    hash = "sha256-uWD3MYkKdCMcIp5UU8TucQnvsyjE+2Ou2JdONH/R+cA=";
  };
  karabiner = extract {
    name = "karabiner-elements-16.0.0";
    src = karabinerDmg;
    artifacts = [ "Karabiner-Elements.pkg" ];
  };
  wireshark = extract {
    name = "wireshark-${casks.wireshark-app.version}";
    src = casks.wireshark-app.src;
    artifacts = [
      "Wireshark.app"
      "Install ChmodBPF.pkg"
      "Add Wireshark to the system path.pkg"
    ];
    sourcePaths = {
      "Wireshark.app" = "Wireshark ${casks.wireshark-app.version}/Wireshark.app";
      "Install ChmodBPF.pkg" = "Wireshark ${casks.wireshark-app.version}/Install ChmodBPF.pkg";
      "Add Wireshark to the system path.pkg" =
        "Wireshark ${casks.wireshark-app.version}/Add Wireshark to the system path.pkg";
    };
  };
  officeEntry = name: app: receipt: {
    inherit name app;
    kind = "pkg";
    version = casks.${name}.version;
    appVersionPrefix = versionPrefix casks.${name}.version;
    bundleId = "com.microsoft.${receipt}";
    teamId = "UBF8T346G9";
    receipts = {
      "com.microsoft.package.Microsoft_${app}.app" = casks.${name}.version;
    };
    packages = [ "${casks.${name}.src}" ];
    running = [ "Microsoft ${app}" ];
  };
  manifest = pkgs.writeText "darwin-installers.json" (
    builtins.toJSON {
      stateDir = "/var/db/dotfiles-installers";
      consoleUser = profile.username;
      packages =
        gui.installers
        ++ [
          {
            name = "azookey";
            kind = "pkg";
            version = casks.azookey.version;
            app = "/Library/Input Methods/azooKeyMac.app";
            appVersion = "1.0";
            bundleId = "dev.ensan.inputmethod.azooKeyMac";
            teamId = "9S3UXHYP65";
            receipts = {
              "dev.ensan.inputmethod.azooKeyMac" = "0";
            };
            packages = [ "${casks.azookey.src}" ];
            legacyPackage = "/opt/homebrew/Caskroom/azookey/${casks.azookey.version}/azooKey-release-signed.pkg";
            legacySha256 = "d389315c928c28da732c4eb2ade8ed0c19c896fdf06f8353ac617d95dcf2b39c";
            running = [ "azooKeyMac" ];
          }
          {
            name = "karabiner-elements";
            kind = "pkg";
            version = "16.0.0";
            app = "/Applications/Karabiner-Elements.app";
            appVersion = "16.0.0";
            bundleId = "org.pqrs.Karabiner-Elements.Settings";
            teamId = "G43BCU2T37";
            receipts = {
              "org.pqrs.Karabiner-Elements" = "16.0.0";
              "org.pqrs.Karabiner-DriverKit-VirtualHIDDevice" = "6.14.0";
            };
            requiredPaths = [ "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice" ];
            packages = [ "${karabiner}/Karabiner-Elements.pkg" ];
            running = [
              "karabiner_grabber"
              "Karabiner-Elements"
            ];
            strictVersion = true;
          }
          {
            name = "tailscale-app";
            kind = "pkg";
            version = casks.tailscale-app.version;
            app = "/Applications/Tailscale.app";
            appVersion = casks.tailscale-app.version;
            bundleId = "io.tailscale.ipn.macsys";
            teamId = "W5364U7YZB";
            receipts = {
              "com.tailscale.ipn.macsys" = casks.tailscale-app.version;
            };
            packages = [ "${casks.tailscale-app.src}" ];
            running = [
              "Tailscale.app"
              "io.tailscale.ipn.macsys"
            ];
          }
          {
            name = "wireshark-app";
            kind = "pkg";
            version = casks.wireshark-app.version;
            app = "/Applications/Wireshark.app";
            appVersion = casks.wireshark-app.version;
            bundleId = "org.wireshark.Wireshark";
            teamId = "7Z6EMTD2C6";
            receipts = {
              "org.wireshark.ChmodBPF.pkg" = "1.2";
              "org.wireshark.path_helper.pkg" = "1.1";
            };
            requiredPaths = [
              "/Library/LaunchDaemons/org.wireshark.ChmodBPF.plist"
              "/etc/paths.d/Wireshark"
            ];
            packages = [
              "${wireshark}/Install ChmodBPF.pkg"
              "${wireshark}/Add Wireshark to the system path.pkg"
            ];
            appSource = "${wireshark}/Wireshark.app";
            running = [ "Wireshark.app" ];
          }
        ]
        ++ lib.optionals host.fullDesktopFeatured [
          {
            name = "microsoft-auto-update";
            kind = "pkg";
            version = casks.microsoft-auto-update.version;
            app = "/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app";
            appVersion = lib.concatStringsSep "." (
              lib.take 2 (lib.splitString "." casks.microsoft-auto-update.version)
            );
            bundleId = "com.microsoft.autoupdate2";
            teamId = "UBF8T346G9";
            receipts = {
              "com.microsoft.package.Microsoft_AutoUpdate.app" = casks.microsoft-auto-update.version;
            };
            packages = [ "${casks.microsoft-auto-update.src}" ];
            running = [ "/Microsoft AutoUpdate\\.app/" ];
          }
          (
            officeEntry "microsoft-excel" "Excel" "Excel"
            // {
              app = "/Applications/Microsoft Excel.app";
              requiredReceipts = [ "com.microsoft.pkg.licensing" ];
            }
          )
          (
            officeEntry "microsoft-onenote" "OneNote" "onenote.mac"
            // {
              app = "/Applications/Microsoft OneNote.app";
            }
          )
          (
            officeEntry "microsoft-powerpoint" "PowerPoint" "Powerpoint"
            // {
              app = "/Applications/Microsoft PowerPoint.app";
              requiredReceipts = [ "com.microsoft.pkg.licensing" ];
            }
          )
          (
            officeEntry "microsoft-word" "Word" "Word"
            // {
              app = "/Applications/Microsoft Word.app";
              requiredReceipts = [ "com.microsoft.pkg.licensing" ];
            }
          )
        ];
      masApps = {
        "Apple Configurator" = 1037126344;
        GarageBand = 682658836;
        iMovie = 408981434;
        Keynote = 409183694;
        LINE = 539883307;
        Numbers = 409203825;
        Pages = 409201541;
        RunCat = 1429033973;
      };
    }
  );
  reconcile = pkgs.writeShellScriptBin "dotfiles-installers" ''
    exec ${pkgs.python3}/bin/python3 ${./files/reconcile.py} "$@" ${manifest} ${pkgs.mas}/bin/mas
  '';
in
delib.scopedModule {
  name = "darwin.installers";
  scope = hostTraits.darwinDesktop;

  options = delib.singleEnableOption hostTraits.darwinDesktop;

  home.ifEnabled = {
    home.packages = gui.packages;
    home.file = gui.cliFiles;
    home.activation.preserveZenProfile = hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./files/preserve-zen-profile.py} \
        ${lib.escapeShellArg "/Users/${profile.username}"} \
        /Applications/Zen.app ${installHash}/bin/firefox-install-hash --literal-install-path
    '';
  };

  darwin.ifEnabled = {
    # LINE for macOS is distributed through the Mac App Store. Preserve the
    # machine's enabled App Store automatic updates rather than copying it.
    system.defaults.CustomSystemPreferences."com.apple.commerce".AutoUpdate = true;
    environment.etc."dotfiles/installers.json".source = manifest;
    environment.systemPackages = [ reconcile ];
    # Copy old Home Manager/Nix Apps links before activation removes their
    # managed targets. All pending apps are preflighted first.
    system.activationScripts.preActivation.text = lib.mkBefore ''
      ${reconcile}/bin/dotfiles-installers --before-nix-apps
    '';
    system.activationScripts.postActivation.text = lib.mkBefore ''
      ${reconcile}/bin/dotfiles-installers
    '';
  };
}
