{
  delib,
  homeDir,
  hostTraits,
  pkgs,
  profile,
  ...
}:
let
  log = "${homeDir}/Library/Logs/chat-diary-refresh.log";
  # The iPhone's UDID stays out of this public repository: write it once per Mac
  # into this untracked file (`xcrun devicectl list devices` shows it).
  udidFile = "${homeDir}/.config/ios-refresh/device-udid";
  refresh = pkgs.writeShellScript "chat-diary-refresh" ''
    set -euo pipefail
    if [ ! -s "${udidFile}" ]; then
      echo "$(date '+%F %T') ${udidFile} is missing; write the iPhone UDID there" >&2
      exit 1
    fi
    exec "${homeDir}/projects/chat-diary/scripts/refresh-device.sh" "$(tr -d '[:space:]' <"${udidFile}")" "$@"
  '';
in
delib.module {
  name = "chat-diary-refresh";

  options = delib.singleEnableOption hostTraits.macbook;

  # The diary app (~/projects/chat-diary) is signed by the same free Personal Team as
  # Orgnote, so its profiles also last 7 days; its script renews like Orgnote's.
  home.ifEnabled.launchd.agents.chat-diary-refresh = {
    enable = true;
    config = {
      ProgramArguments = [
        "${refresh}"
        "dev.tenelol.diary"
        "7G85M3YH8D"
      ];
      StartInterval = 6 * 60 * 60;
      RunAtLoad = true;
      ProcessType = "Background";
      EnvironmentVariables = {
        # devicectl and xcodebuild fail without a user name in the environment.
        USER = profile.username;
        HOME = homeDir;
        PATH = "${pkgs.bash}/bin:${pkgs.xcodegen}/bin:${pkgs.git}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = log;
      StandardErrorPath = log;
    };
  };
}
