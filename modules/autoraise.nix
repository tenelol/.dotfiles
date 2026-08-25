{
  delib,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
  autoraisePackage =
    if host.name == "macbook" then
      pkgs.autoraise.overrideAttrs (_: {
        # cctools-binutils from Nix crashes on macOS 26 while linking
        # AutoRaise. Use the working system toolchain for this small
        # macOS-only GUI utility instead.
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
      })
    else
      pkgs.autoraise;
in
delib.module {
  name = "autoraise";

  options = delib.singleEnableOption false;

  darwin.ifEnabled = lib.mkIf isDarwinDesktop {
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

  home.ifEnabled = lib.mkIf isDarwinDesktop {
    home.packages = [ autoraisePackage ];

    xdg.configFile."AutoRaise/config".source = ./autoraise/files/config;
  };
}
