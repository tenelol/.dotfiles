{
  delib,
  homeDir,
  hostTraits,
  lib,
  pkgs,
  profile,
  ...
}:
let
  # The iPhone's UDID stays out of this public repository: write it once per Mac
  # into this untracked file (`xcrun devicectl list devices` shows it).
  udidFile = "${homeDir}/.config/ios-refresh/device-udid";

  # Apps signed by a free Personal Team have profiles that last 7 days. Each
  # project's script renews and reinstalls on the iPhone once fewer than 3 days
  # remain, whenever the phone is reachable.
  mkAgent =
    name:
    {
      project,
      args ? [ ],
      extraPackages ? [ ],
    }:
    let
      log = "${homeDir}/Library/Logs/${name}.log";
      refresh = pkgs.writeShellScript name ''
        set -euo pipefail
        if [ ! -s "${udidFile}" ]; then
          echo "$(date '+%F %T') ${udidFile} is missing; write the iPhone UDID there" >&2
          exit 1
        fi
        exec "${homeDir}/projects/${project}/scripts/refresh-device.sh" "$(tr -d '[:space:]' <"${udidFile}")"${
          lib.optionalString (args != [ ]) " \"$@\""
        }
      '';
    in
    {
      enable = true;
      config = {
        ProgramArguments = [ "${refresh}" ] ++ args;
        StartInterval = 6 * 60 * 60;
        RunAtLoad = true;
        ProcessType = "Background";
        EnvironmentVariables = {
          # devicectl and xcodebuild fail without a user name in the environment.
          USER = profile.username;
          HOME = homeDir;
          PATH = "${
            lib.makeBinPath (
              [
                pkgs.bash
                pkgs.xcodegen
              ]
              ++ extraPackages
            )
          }:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        StandardOutPath = log;
        StandardErrorPath = log;
      };
    };
in
delib.module {
  name = "ios-refresh";

  options = delib.singleEnableOption hostTraits.macbook;

  home.ifEnabled.launchd.agents = lib.mapAttrs mkAgent {
    orgnote-refresh.project = "orgnote";
    chat-diary-refresh = {
      project = "chat-diary";
      args = [
        "dev.tenelol.diary"
        "7G85M3YH8D"
      ];
      extraPackages = [ pkgs.git ];
    };
  };
}
