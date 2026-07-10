{
  host,
  pkgs,
  lib,
  config,
  inputs,
  profile,
  ...
}:
let
  isServer = host.isServer or false;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  homeDir = config.home.homeDirectory;
  homePackages = import ../lib/home-packages.nix {
    inherit pkgs lib inputs;
  };
in
{
  home.username = lib.mkDefault profile.username;
  home.homeDirectory = lib.mkDefault (
    if isDarwin then "/Users/${config.home.username}" else "/home/${config.home.username}"
  );
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

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.packages = homePackages.forHost {
    inherit isServer;
    fullDesktop = host.fullDesktopFeatured;
  };

  home.file =
    lib.optionalAttrs (!isServer) {
      ".local/bin/ushi" = {
        source = ../config/scripts/ushi;
        executable = true;
      };
    }
    // lib.optionalAttrs (!isServer && isLinux) {
      ".local/bin/emoji-fuzzel" = {
        source = ../config/scripts/emoji-fuzzel;
        executable = true;
      };
      ".local/bin/niri-screenshot" = {
        source = ../config/scripts/niri-screenshot;
        executable = true;
      };
    }
    // lib.optionalAttrs (!isServer) {
      ".config/fontconfig/fonts.conf".source = ../config/fontconfig/fonts.conf;
    };

  xdg.configFile = lib.optionalAttrs (!isServer && isLinux) {
    "fcitx5/conf/classicui.conf".source = ../config/fcitx5/classicui.conf;
  };
}
