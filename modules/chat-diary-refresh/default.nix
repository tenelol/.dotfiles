{
  delib,
  hostTraits,
  pkgs,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
  log = "${homeDir}/Library/Logs/chat-diary-refresh.log";
in
delib.scopedModule {
  name = "chat-diary-refresh";
  scope = hostTraits.macbook;

  options = delib.singleEnableOption hostTraits.macbook;

  # The diary app (~/projects/chat-diary) is signed by the same free Personal Team as
  # Orgnote, so its profiles also last 7 days; its script renews like Orgnote's.
  home.ifEnabled.launchd.agents.chat-diary-refresh = {
    enable = true;
    config = {
      ProgramArguments = [
        "${homeDir}/projects/chat-diary/scripts/refresh-device.sh"
        # iPhone 17e "Tener"
        "00008150-001D542E3E33401C"
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
