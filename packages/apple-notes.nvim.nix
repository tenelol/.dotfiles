{ pkgs }:
pkgs.vimUtils.buildVimPlugin {
  pname = "apple-notes.nvim";
  version = "unstable-2026-03-24";

  dependencies = with pkgs.vimPlugins; [
    neo-tree-nvim
    nui-nvim
    plenary-nvim
    telescope-nvim
  ];

  src = pkgs.fetchFromGitHub {
    owner = "rdrkr";
    repo = "apple-notes.nvim";
    rev = "e78bf81358be75dd353b7e96125f3d39d42e7fee";
    hash = "sha256-MjNsWaWv3ugQQ/d+tmPUnSAZTGeA1pIBnWfU0WHs5RQ=";
  };
}
