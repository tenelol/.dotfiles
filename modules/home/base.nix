{
  delib,
  pkgs,
  lib,
  profile,
  ...
}:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  homeDir = if isDarwin then "/Users/${profile.username}" else "/home/${profile.username}";
in
delib.module {
  name = "home";

  home.always = {
    home.username = lib.mkDefault profile.username;
    home.homeDirectory = lib.mkDefault homeDir;
    home.stateVersion = "25.05";
    home.enableNixpkgsReleaseCheck = false;

    home.sessionPath = [
      "${homeDir}/.npm-global/bin"
      "${homeDir}/.local/bin"
    ]
    ++ lib.optionals isLinux [
      "/run/wrappers/bin"
    ]
    ++ lib.optionals isDarwin [
      "/opt/homebrew/opt/coreutils/libexec/gnubin"
      "/opt/homebrew/opt/findutils/libexec/gnubin"
      "/opt/homebrew/opt/gawk/libexec/gnubin"
      "/opt/homebrew/opt/gnu-sed/libexec/gnubin"
      "/opt/homebrew/opt/gnu-tar/libexec/gnubin"
      "/opt/homebrew/opt/grep/libexec/gnubin"
      "/opt/homebrew/opt/llvm/bin"
      "/opt/homebrew/opt/make/libexec/gnubin"
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
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
