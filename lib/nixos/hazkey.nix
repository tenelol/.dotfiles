{
  host,
  inputs,
  pkgs,
}:
let
  nix-hazkey = inputs.nix-hazkey;
  inherit (pkgs.stdenv.hostPlatform) system;

  hosts = [
    "nixos"
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

  hasLibllamaCpu = isSupportedSystem && builtins.hasAttr "libllama-cpu" packages;
  libllamaVersion = "20251109.0";
  libllamaSrc =
    if hasLibllamaCpu then
      pkgs.fetchzip {
        name = "libllama-cpu-bin";
        version = libllamaVersion;
        urls = [
          "https://github.com/7ka-Hiira/llama.cpp/releases/download/v${libllamaVersion}/llama-linux-x86_64-cpu-v${libllamaVersion}.tar.gz"
          "https://ghproxy.net/https://github.com/7ka-Hiira/llama.cpp/releases/download/v${libllamaVersion}/llama-linux-x86_64-cpu-v${libllamaVersion}.tar.gz"
          "https://github.moeyy.xyz/https://github.com/7ka-Hiira/llama.cpp/releases/download/v${libllamaVersion}/llama-linux-x86_64-cpu-v${libllamaVersion}.tar.gz"
        ];
        hash = "sha256-Hw96OYrd3LoePFhNk3Whk90I0pREx2gpxanIMxo+bHs=";
        stripRoot = false;
      }
    else
      null;
in
{
  inherit
    enabled
    hosts
    isSupportedSystem
    packages
    ;

  fcitx5Addon = overrideHazkeySrc "fcitx5-hazkey";
  settings = overrideHazkeySrc "hazkey-settings";
  server = overrideHazkeySrc "hazkey-server";
  dictionary = overrideHazkeySrc "dictionary";

  libllamaCpu =
    if hasLibllamaCpu then
      packages.libllama-cpu.overrideAttrs (_: {
        src = libllamaSrc;
      })
    else
      null;
}
