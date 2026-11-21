{
  delib,
  homeDir,
  desktopSelection,
  hostTraits,
  pkgs,
  profile,
  stopDarwinWindowManager,
  ...
}:
let
  # cctools-binutils from Nix crashes on macOS 26 while linking AutoRaise.
  # Use the working system toolchain for this small macOS-only GUI utility
  # instead. The module is scoped to Darwin desktops, so no other branch is
  # needed.
  autoraisePackage = pkgs.autoraise.overrideAttrs (_: {
    buildPhase = ''
      runHook preBuild
      /usr/bin/env -u DEVELOPER_DIR -u SDKROOT PATH=/usr/bin:/bin \
        /Library/Developer/CommandLineTools/usr/bin/clang++ \
        -isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
        -std=c++03 -fobjc-arc \
        '-DNS_FORMAT_ARGUMENT(A)=' \
        '-DSKYLIGHT_AVAILABLE=1' \
        -F/System/Library/PrivateFrameworks \
        -o AutoRaise AutoRaise.mm \
        -framework AppKit -framework SkyLight
      bash create-app-bundle.sh
      runHook postBuild
    '';
  });
in
delib.scopedModule {
  name = "autoraise";
  scope = hostTraits.darwinDesktop;

  options = delib.moduleOptions {
    enable = delib.readOnly (delib.boolOption desktopSelection.autoraise);
  };

  darwin.ifDisabled.system.activationScripts.preActivation.text = stopDarwinWindowManager {
    labels = [ "org.nixos.autoraise" ];
    processes = [
      "AutoRaise"
      "autoraise"
    ];
  };

  darwin.ifEnabled = {
    launchd.user.agents.autoraise = {
      serviceConfig = {
        ProgramArguments = [
          "${autoraisePackage}/bin/autoraise"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        EnvironmentVariables = {
          USER = profile.username;
          HOME = homeDir;
        };
      };

      managedBy = "autoraise";
    };
  };

  home.ifEnabled = {
    home.packages = [ autoraisePackage ];

    xdg.configFile."AutoRaise/config".source = ./files/config;
  };
}
