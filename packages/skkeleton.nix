{ pkgs }:
pkgs.vimUtils.buildVimPlugin {
  pname = "skkeleton";
  version = "2.0.2";

  src = pkgs.fetchFromGitHub {
    owner = "vim-skk";
    repo = "skkeleton";
    rev = "42b7b62062e5eb4ba157b9e8d12a104777bbd9b3";
    hash = "sha256-FqGK4IgD75etYRpdr4NaBHQvlBL5Cx9q0SOy+IoUXoU=";
  };
}
