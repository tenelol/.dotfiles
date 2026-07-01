{ delib, pkgs, ... }:
let
  fish = import ../../lib/fish.nix { inherit pkgs; };
in
delib.module {
  name = "shell.fish";

  home.always = fish.homeConfig;
}
