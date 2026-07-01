{ pkgs }:
let
  runtime = import ./nvim-runtime.nix { inherit pkgs; };
in
runtime
// {
  nixvimProgram = import ./nvim-settings.nix {
    inherit pkgs;
    nvim = runtime;
  };
}
