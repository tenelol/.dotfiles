{
  delib,
  hostTraits,
  lib,
  profile,
  ...
}:
let
  homeDir = (if hostTraits.darwin then "/Users/" else "/home/") + profile.username;
in
delib.module {
  name = "home";

  # Other modules take the user's home directory as the homeDir argument.
  myconfig.always.args.shared = { inherit homeDir; };

  home.always = {
    home.username = lib.mkDefault profile.username;
    home.homeDirectory = lib.mkDefault homeDir;
    home.stateVersion = "25.05";
    home.enableNixpkgsReleaseCheck = false;

    home.sessionPath = [
      "${homeDir}/.npm-global/bin"
      "${homeDir}/.local/bin"
    ]
    ++ lib.optionals hostTraits.linux [
      "/run/wrappers/bin"
    ]
    ++ lib.optionals hostTraits.darwin [
      "/usr/local/bin"
      "/usr/local/sbin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
    ];

    home.sessionVariables.EDITOR = "nvim";
  };
}
