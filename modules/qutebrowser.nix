{
  delib,
  host,
  pkgs,
  ...
}:
let
  qutebrowser = import ../lib/qutebrowser.nix { inherit pkgs; };
in
delib.module {
  name = "qutebrowser";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    programs.qutebrowser = qutebrowser.program;
    programs.fish.shellAliases = qutebrowser.fishAliases;
  };
}
