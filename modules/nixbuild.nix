{
  delib,
  lib,
  pkgs,
  ...
}:
let
  defaultIdentityFile =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "/var/root/.ssh/nixbuild_ed25519"
    else
      "/root/.ssh/nixbuild_ed25519";

  buildMachines =
    map
      (system: {
        hostName = "eu.nixbuild.net";
        inherit system;
        maxJobs = 100;
        speedFactor = 1;
        supportedFeatures = [
          "benchmark"
          "big-parallel"
        ];
      })
      [
        "x86_64-linux"
        "aarch64-linux"
      ];

  config =
    { myconfig, ... }:
    let
      cfg = myconfig.nixbuild;
    in
    lib.mkIf cfg.enable {
      programs.ssh = {
        extraConfig = ''
          Host eu.nixbuild.net
            PubkeyAcceptedKeyTypes ssh-ed25519
            ServerAliveInterval 60
            IPQoS throughput
            IdentityFile ${cfg.identityFile}
        '';

        knownHosts.nixbuild = {
          hostNames = [ "eu.nixbuild.net" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
        };
      };

      nix = {
        distributedBuilds = true;
        buildMachines = buildMachines;
        settings = {
          builders-use-substitutes = true;
          max-jobs = lib.mkDefault cfg.localMaxJobs;
        };
      };
    };
in
delib.module {
  name = "nixbuild";

  options =
    with delib;
    moduleOptions {
      enable = boolOption false;
      identityFile = strOption defaultIdentityFile;
      localMaxJobs = intOption 1;
    };

  nixos.always = config;
  darwin.always = config;
}
