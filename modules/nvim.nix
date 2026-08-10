{
  delib,
  host,
  lib,
  pkgs,
  hm,
  ...
}:
let
  nvim = import ../lib/nvim.nix { inherit pkgs; };
in
delib.module {
  name = "nvim";

  home.always = lib.mkIf (!host.isServer) {
    programs.nixvim = nvim.nixvimProgram;

    xdg.dataFile."jupyter/kernels/nix-python3/kernel.json".text = nvim.jupyterKernelSpecJson;
    home.file."Library/Jupyter/kernels/nix-python3/kernel.json".text = nvim.jupyterKernelSpecJson;

    home.activation.cleanupLegacyLazyNvim = hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -e "$HOME/.local/share/nvim/lazy/lazy.nvim" ]; then
        $DRY_RUN_CMD rm -rf "$HOME/.local/share/nvim/lazy/lazy.nvim"
      fi
    '';
  };
}
