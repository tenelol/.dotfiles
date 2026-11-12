{
  delib,
  host,
  hostTraits,
  inputs,
  pkgs,
  ...
}:
let
  inherit (inputs) nix-hazkey;

  # The pinned upstream binary release only exists for x86_64-linux.
  supported = host.system == "x86_64-linux";

  hazkeyVersion = "0.2.1";
  hazkeySrc = pkgs.fetchzip {
    name = "fcitx5-hazkey-bin";
    version = hazkeyVersion;
    urls = [
      "https://github.com/7ka-Hiira/fcitx5-hazkey/releases/download/${hazkeyVersion}/fcitx5-hazkey-${hazkeyVersion}-x86_64.tar.gz"
      "https://ghproxy.net/https://github.com/7ka-Hiira/fcitx5-hazkey/releases/download/${hazkeyVersion}/fcitx5-hazkey-${hazkeyVersion}-x86_64.tar.gz"
      "https://github.moeyy.xyz/https://github.com/7ka-Hiira/fcitx5-hazkey/releases/download/${hazkeyVersion}/fcitx5-hazkey-${hazkeyVersion}-x86_64.tar.gz"
    ];
    hash = "sha256-jwv1UTRz/FVHmeaumwP45Q4JZcSuZHTrF2/PAzrxeC8=";
    stripRoot = false;
  };

  packages = nix-hazkey.packages.${host.system};
  overrideHazkeySrc =
    name:
    packages.${name}.overrideAttrs (_: {
      src = hazkeySrc;
    });
in
delib.module {
  name = "nixos.hazkey";

  options = delib.singleEnableOption (hostTraits.linuxDesktop && supported);

  nixos.always.imports = [ nix-hazkey.nixosModules.hazkey ];

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
