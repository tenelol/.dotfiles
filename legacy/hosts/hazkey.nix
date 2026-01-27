{ pkgs, nix-hazkey, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  hazkeyVersion = "0.2.0";
  hazkeySrc = pkgs.fetchzip {
    name = "fcitx5-hazkey-bin";
    version = hazkeyVersion;
    urls = [
      "https://github.com/7ka-Hiira/fcitx5-hazkey/releases/download/${hazkeyVersion}/fcitx5-hazkey-${hazkeyVersion}-x86_64.tar.gz"
      "https://ghproxy.net/https://github.com/7ka-Hiira/fcitx5-hazkey/releases/download/${hazkeyVersion}/fcitx5-hazkey-${hazkeyVersion}-x86_64.tar.gz"
      "https://github.moeyy.xyz/https://github.com/7ka-Hiira/fcitx5-hazkey/releases/download/${hazkeyVersion}/fcitx5-hazkey-${hazkeyVersion}-x86_64.tar.gz"
    ];
    hash = "sha256-agpqU8uVpmGJEnqQPsZBv3uSOw9pD0iri3/R/hRAACA=";
    stripRoot = false;
  };

  hazkeyPackages = nix-hazkey.packages.${system};
  fcitx5Hazkey = hazkeyPackages.fcitx5-hazkey.overrideAttrs (_: { src = hazkeySrc; });
  hazkeySettings = hazkeyPackages.hazkey-settings.overrideAttrs (_: { src = hazkeySrc; });
  hazkeyServer = hazkeyPackages.hazkey-server.overrideAttrs (_: { src = hazkeySrc; });
  hazkeyDictionary = hazkeyPackages.dictionary.overrideAttrs (_: { src = hazkeySrc; });

  libllamaVersion = "20251109.0";
  libllamaSrc = pkgs.fetchzip {
    name = "libllama-cpu-bin";
    version = libllamaVersion;
    urls = [
      "https://ghproxy.net/https://github.com/7ka-Hiira/llama.cpp/releases/download/v${libllamaVersion}/llama-linux-x86_64-cpu-v${libllamaVersion}.tar.gz"
      "https://github.moeyy.xyz/https://github.com/7ka-Hiira/llama.cpp/releases/download/v${libllamaVersion}/llama-linux-x86_64-cpu-v${libllamaVersion}.tar.gz"
    ];
    hash = "sha256-Hw96OYrd3LoePFhNk3Whk90I0pREx2gpxanIMxo+bHs=";
    stripRoot = false;
  };
  libllamaCpu = hazkeyPackages.libllama-cpu.overrideAttrs (_: { src = libllamaSrc; });
in
{
  imports = [
    nix-hazkey.nixosModules.hazkey
  ];

  # IME
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-skk
        fcitx5Hazkey
      ];
    };
  };

  # Ensure Fcitx5 input method definitions are visible in the system profile.
  environment.pathsToLink = [
    "/share/fcitx5"
  ];

  services.hazkey = {
    enable = true;
    installFcitx5Addon = false;
    installHazkeySettings = false;
    server.package = hazkeyServer;
    libllama.package = libllamaCpu;
    dictionary.package = hazkeyDictionary;
    zenzai.package = hazkeyPackages.zenzai_v3_1-small;
  };

  environment.systemPackages = [
    hazkeySettings
  ];
}
