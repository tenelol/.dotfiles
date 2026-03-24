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
  hasHazkeyPackages = builtins.hasAttr system nix-hazkey.packages;
  hasX86_64Binary = system == "x86_64-linux";
  isSupportedHazkeySystem = hasHazkeyPackages && hasX86_64Binary;

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

  hazkeyPackages = if hasHazkeyPackages then nix-hazkey.packages.${system} else null;
  fcitx5Hazkey =
    if isSupportedHazkeySystem then
      hazkeyPackages.fcitx5-hazkey.overrideAttrs (_: {
        src = hazkeySrc;
      })
    else
      null;
  hazkeySettings =
    if isSupportedHazkeySystem then
      hazkeyPackages.hazkey-settings.overrideAttrs (_: {
        src = hazkeySrc;
      })
    else
      null;
  hazkeyServer =
    if isSupportedHazkeySystem then
      hazkeyPackages.hazkey-server.overrideAttrs (_: {
        src = hazkeySrc;
      })
    else
      null;
  hazkeyDictionary =
    if isSupportedHazkeySystem then
      hazkeyPackages.dictionary.overrideAttrs (_: {
        src = hazkeySrc;
      })
    else
      null;
  hasLibllamaCpu = isSupportedHazkeySystem && builtins.hasAttr "libllama-cpu" hazkeyPackages;

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
  libllamaCpu =
    if hasLibllamaCpu then
      hazkeyPackages.libllama-cpu.overrideAttrs (_: {
        src = libllamaSrc;
      })
    else
      null;
in
delib.module {
  name = "nixos.hazkey";

  options = delib.singleEnableOption (!host.isServer && isSupportedHazkeySystem);

  # Always import the hazkey NixOS module so its options are defined on every host.
  # Actual configuration is guarded by ifEnabled below.
  nixos.always = {
    imports = [ nix-hazkey.nixosModules.hazkey ];
    warnings =
      lib.optional
        (!host.isServer && builtins.match ".*-linux" host.system != null && !isSupportedHazkeySystem)
        "nixos.hazkey is disabled on ${system}: the pinned upstream binary overrides are only packaged for x86_64-linux.";
  };

  nixos.ifEnabled = {
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

    environment.pathsToLink = [ "/share/fcitx5" ];

    services.hazkey = {
      enable = true;
      installFcitx5Addon = false;
      installHazkeySettings = false;
      server.package = hazkeyServer;
      libllama.package = libllamaCpu;
      dictionary.package = hazkeyDictionary;
      zenzai.package = hazkeyPackages.zenzai_v3_1-small;
    };

    environment.systemPackages = [ hazkeySettings ];
  };
}
