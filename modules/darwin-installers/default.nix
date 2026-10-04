{
  delib,
  host,
  hostTraits,
  lib,
  pkgs,
  profile,
  config,
  ...
}:
let
  extract = pkgs.callPackage ../../packages/macos-installer-source.nix { };
  casks = pkgs.brewCasks;
  brewCask = pkgs.callPackage ../../packages/brew-cask.nix { };
  apps = builtins.fromJSON (builtins.readFile ../brew-casks/files/apps.json);
  selectedApps = apps.base ++ lib.optionals host.fullDesktopFeatured apps.fullDesktop;
  selfUpdatingCask =
    spec:
    let
      cask = casks.${spec.name};
      package = brewCask (
        builtins.removeAttrs spec [
          "name"
          "selfUpdating"
        ]
        // {
          inherit cask;
        }
      );
      version = lib.head (lib.splitString "," cask.version);
      app = spec.selfUpdating.app;
    in
    {
      inherit (spec) name;
      inherit (spec.selfUpdating) bundleId teamId;
      inherit version;
      kind = "app";
      app = "/Applications/${app}.app";
      appVersion = version;
      source = "${package}/Applications/${app}.app";
      owner = profile.username;
      selfUpdating = true;
      running = [ "/${app}\\.app/" ];
    };
  boringNotch = pkgs.callPackage ../../packages/boringnotch.nix { };
  chatgpt = casks.chatgpt.overrideAttrs {
    version = "26.930.41038";
    src = pkgs.fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/ChatGPT-darwin-arm64-26.930.41038.zip";
      hash = "sha256-9s9NLptpru+jOt2kvNGi0wY1f1JToaxgSXAIcMKN0Mc=";
    };
  };
  classic = casks.chatgpt-classic.overrideAttrs {
    src = pkgs.fetchurl {
      name = "ChatGPT_Classic-1.2026.184.dmg";
      url = "https://persistent.oaistatic.com/classic/public/ChatGPT_Classic.dmg";
      hash = "sha256-qUEX+zRicim6r+Pot7RUZ8Wu54YbTNeVpb6NVHsf97Q=";
    };
  };
  selfUpdatingApp =
    name: app: bundleId: teamId:
    let
      cask =
        if name == "chatgpt" then
          chatgpt
        else if name == "chatgpt-classic" then
          classic
        else
          casks.${name};
      package = brewCask { inherit cask; };
      version = lib.head (lib.splitString "," cask.version);
    in
    {
      inherit
        name
        version
        bundleId
        teamId
        ;
      kind = "app";
      app = "/Applications/${app}.app";
      appVersion = version;
      source = "${package}/Applications/${app}.app";
      owner = profile.username;
      selfUpdating = true;
      running = [ "/${app}\\.app/" ];
    }
    // lib.optionalAttrs (name == "chatgpt") {
      orphanHelpers = [
        "browser_crashpad_handler"
        "bare-modifier-monitor"
      ];
    };
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
  docker = extract {
    name = "docker-desktop-${casks.docker-desktop.version}";
    src = casks.docker-desktop.src;
    artifacts = [ "Docker.app" ];
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
      packages = [
        (selfUpdatingApp "chatgpt" "ChatGPT" "com.openai.codex" "2DC432GLL2")
        (selfUpdatingApp "chatgpt-classic" "ChatGPT Classic" "com.openai.chat" "2DC432GLL2")
        (selfUpdatingApp "thebrowsercompany-dia" "Dia" "company.thebrowser.dia" "S6N382Y83G")
        (selfUpdatingApp "claude" "Claude" "com.anthropic.claudefordesktop" "Q6L2SF6YDW")
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
      ++ map selfUpdatingCask (builtins.filter (app: app ? selfUpdating) selectedApps)
      ++ lib.optionals config.myconfig.boringnotch.enable [
        {
          name = "boringnotch";
          kind = "app";
          version = boringNotch.version;
          app = "/Applications/boringNotch.app";
          appVersion = boringNotch.version;
          bundleId = "theboringteam.boringnotch";
          teamId = "JPWMG84CH8";
          source = "${boringNotch}/Applications/boringNotch.app";
          owner = profile.username;
          selfUpdating = true;
          migrateBeforeNixApps = true;
          running = [ "/boringNotch\\.app/" ];
        }
      ]
      ++ lib.optionals host.fullDesktopFeatured [
        (selfUpdatingApp "discord" "Discord" "com.hnc.Discord" "53Q6R32WPB")
        (selfUpdatingApp "slack" "Slack" "com.tinyspeck.slackmacgap" "BQR82RBBHL")
        {
          name = "docker-desktop";
          kind = "app";
          version = lib.head (lib.splitString "," casks.docker-desktop.version);
          app = "/Applications/Docker.app";
          appVersion = lib.head (lib.splitString "," casks.docker-desktop.version);
          bundleId = "com.docker.docker";
          teamId = "9BNSXJN65R";
          source = "${docker}/Docker.app";
          owner = profile.username;
          selfUpdating = true;
          running = [
            "Docker.app"
            "com.docker.backend"
            "com.docker.virtualization"
          ];
        }
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

  darwin.ifEnabled = {
    # LINE for macOS is distributed through the Mac App Store. Preserve the
    # machine's enabled App Store automatic updates rather than copying it.
    system.defaults.CustomSystemPreferences."com.apple.commerce".AutoUpdate = true;
    environment.etc."dotfiles/installers.json".source = manifest;
    environment.systemPackages = [ reconcile ];
    # Preserve copies that previously lived in Nix Apps before Darwin removes
    # their old managed bundles. All pending apps are preflighted first.
    system.activationScripts.preActivation.text = lib.mkBefore ''
      ${reconcile}/bin/dotfiles-installers --before-nix-apps
    '';
    system.activationScripts.postActivation.text = lib.mkBefore ''
      ${reconcile}/bin/dotfiles-installers
    '';
  };
}
