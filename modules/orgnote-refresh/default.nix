{
  delib,
  hostTraits,
  pkgs,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
  log = "${homeDir}/Library/Logs/orgnote-refresh.log";
  # The iPhone's UDID stays out of this public repository: write it once per Mac
  # into this untracked file (`xcrun devicectl list devices` shows it).
  udidFile = "${homeDir}/.config/ios-refresh/device-udid";
  refresh = pkgs.writeShellScript "orgnote-refresh" ''
    set -euo pipefail
    if [ ! -s "${udidFile}" ]; then
      echo "$(date '+%F %T') ${udidFile} is missing; write the iPhone UDID there" >&2
      exit 1
    fi
    exec "${homeDir}/projects/orgnote/scripts/refresh-device.sh" "$(tr -d '[:space:]' <"${udidFile}")"
  '';
in
delib.scopedModule {
  name = "orgnote-refresh";
  scope = hostTraits.macbook;

  options = delib.singleEnableOption hostTraits.macbook;

  # Orgnote (~/projects/orgnote) is signed by a free Personal Team, whose
  # profiles last 7 days. Its script renews and reinstalls on the iPhone
  # once fewer than 3 days remain, whenever the phone is reachable.
  home.ifEnabled.launchd.agents.orgnote-refresh = {
    enable = true;
    config = {
      ProgramArguments = [
        "${refresh}"
      ];
      StartInterval = 6 * 60 * 60;
      RunAtLoad = true;
      ProcessType = "Background";
      EnvironmentVariables = {
        # devicectl and xcodebuild fail without a user name in the environment.
        USER = profile.username;
        HOME = homeDir;
        PATH = "${pkgs.bash}/bin:${pkgs.xcodegen}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = log;
      StandardErrorPath = log;
    };
  };
}
