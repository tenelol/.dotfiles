{
  delib,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  nix-hazkey = inputs.nix-hazkey;
  inherit (pkgs.stdenv.hostPlatform) system;

  hosts = [
    "surface"
    "nvidia-desktop"
  ];

  enabled = builtins.elem host.name hosts;
  hasPackages = builtins.hasAttr system nix-hazkey.packages;
  hasX86_64Binary = system == "x86_64-linux";
  isSupportedSystem = hasPackages && hasX86_64Binary;

  hazkeyVersion = "0.2.1";
  hazkeySrc =
    if hasX86_64Binary then
      pkgs.fetchzip {
        name = "fcitx5-hazkey-bin";
        version = hazkeyVersion;
        urls = [
          "https://github.com/7ka-Hiira/fcitx5-hazkey/releases/download/${hazkeyVersion}/fcitx5-hazkey-${hazkeyVersion}-x86_64.tar.gz"
          "https://ghproxy.net/https://github.com/7ka-Hiira/fcitx5-hazkey/releases/download/${hazkeyVersion}/fcitx5-hazkey-${hazkeyVersion}-x86_64.tar.gz"
          "https://github.moeyy.xyz/https://github.com/7ka-Hiira/fcitx5-hazkey/releases/download/${hazkeyVersion}/fcitx5-hazkey-${hazkeyVersion}-x86_64.tar.gz"
        ];
        hash = "sha256-jwv1UTRz/FVHmeaumwP45Q4JZcSuZHTrF2/PAzrxeC8=";
        stripRoot = false;
      }
    else
      null;

  packages = if hasPackages then nix-hazkey.packages.${system} else null;
  overrideHazkeySrc =
    name:
    if isSupportedSystem then
      packages.${name}.overrideAttrs (_: {
        src = hazkeySrc;
      })
    else
      null;

in
delib.module {
  name = "nixos.hazkey";

  options = delib.singleEnableOption (enabled && isSupportedSystem);

  nixos.always = {
    imports = [ inputs.nix-hazkey.nixosModules.hazkey ];

    warnings =
      lib.optional
        (enabled && !host.isServer && builtins.match ".*-linux" host.system != null && !isSupportedSystem)
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
          (overrideHazkeySrc "fcitx5-hazkey")
        ];
      };
    };

    environment.pathsToLink = [ "/share/fcitx5" ];

    services.hazkey = {
      enable = true;
      installFcitx5Addon = false;
      installHazkeySettings = false;
      server.package = overrideHazkeySrc "hazkey-server";
      dictionary.package = overrideHazkeySrc "dictionary";
      zenzai.package = packages.zenzai_v3_1-small;
    };

    environment.systemPackages = [ (overrideHazkeySrc "hazkey-settings") ];
  };
}
