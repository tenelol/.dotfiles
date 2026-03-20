{ pkgs }:
pkgs.vimUtils.buildVimPlugin {
  pname = "winresizer";
  version = "unstable-2022-08-15";

  src = pkgs.fetchFromGitHub {
    owner = "simeji";
    repo = "winresizer";
    rev = "9bd559a03ccec98a458e60c705547119eb5350f3";
    hash = "sha256-5LR9A23BvpCBY9QVSF9PadRuDSBjv+knHSmdQn/3mH0=";
  };
}
