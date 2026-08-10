{
  delib,
  host,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "lazygit";

  home.always = lib.mkIf (!host.isServer) (
    {
      home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.lazygit ];
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      xdg.configFile."lazygit/config.yml".source = ../config/lazygit/config.yml;
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      home.file."Library/Application Support/lazygit/config.yml".source = ../config/lazygit/config.yml;
    }
  );
}
