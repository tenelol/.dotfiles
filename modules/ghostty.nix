{
  delib,
  host,
  pkgs,
  ...
}:
let
  ghosttyConfig =
    if pkgs.stdenv.hostPlatform.isDarwin then
      ../config/ghostty/config-darwin
    else
      ../config/ghostty/config;
in
delib.module {
  name = "ghostty";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile."ghostty/config".source = ghosttyConfig;
  };
}
