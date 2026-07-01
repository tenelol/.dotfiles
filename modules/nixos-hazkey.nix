{
  delib,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  hazkey = import ../lib/nixos/hazkey.nix { inherit host inputs pkgs; };
in
delib.module {
  name = "nixos.hazkey";

  options = delib.singleEnableOption (hazkey.enabled && hazkey.isSupportedSystem);

  nixos.always =
    { ... }:
    {
      warnings =
        lib.optional
          (
            hazkey.enabled
            && !host.isServer
            && builtins.match ".*-linux" host.system != null
            && !hazkey.isSupportedSystem
          )
          "nixos.hazkey is enabled for ${host.name}, but the pinned upstream binary overrides are only packaged for x86_64-linux.";
    };

  nixos.ifEnabled = {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [
          fcitx5-skk
          hazkey.fcitx5Addon
        ];
      };
    };

    environment.pathsToLink = [ "/share/fcitx5" ];

    services.hazkey = {
      enable = true;
      installFcitx5Addon = false;
      installHazkeySettings = false;
      server.package = hazkey.server;
      libllama.package = hazkey.libllamaCpu;
      dictionary.package = hazkey.dictionary;
      zenzai.package = hazkey.packages.zenzai_v3_1-small;
    };

    environment.systemPackages = [ hazkey.settings ];
  };
}
