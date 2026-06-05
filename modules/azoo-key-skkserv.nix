{
  delib,
  host,
  pkgs,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
  azooKeySkkserv = pkgs.callPackage ../packages/azoo-key-skkserv.nix { };
in
delib.module {
  name = "azoo-key-skkserv";

  options = delib.singleEnableOption (
    host.name == "macbook" && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    environment.systemPackages = [
      azooKeySkkserv
    ];

    launchd.user.agents.azoo-key-skkserv = {
      serviceConfig = {
        Label = "dev.ensan.azoo-key-skkserv";
        ProgramArguments = [
          "${azooKeySkkserv}/bin/azoo-key-skkserv"
          "--incoming-charset"
          "EUC-JP"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${homeDir}/Library/Logs/azoo-key-skkserv.log";
        StandardErrorPath = "${homeDir}/Library/Logs/azoo-key-skkserv.log";
        EnvironmentVariables = {
          USER = profile.username;
          HOME = homeDir;
          PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
      };

      managedBy = "azoo-key-skkserv";
    };
  };
}
