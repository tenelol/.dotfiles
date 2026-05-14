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
  ghosttyAuroraShader =
    pkgs.runCommand "ghostty-aurora-tokyo-night.glsl"
      {
        src = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/cmmichael/ghostty-aurora/f75dc3ade01197ee0ba18e1d90cbdaef9a0a33ba/aurora.glsl";
          hash = "sha256-HrlQWPSOsteyrZ/3PqOIie7K5Rqv40m18aRWdfWQWP0=";
        };
      }
      ''
        substitute "$src" "$out" \
          --replace-fail '#define ACTIVE_THEME THEME_AURORA' '#define ACTIVE_THEME THEME_TOKYO_NIGHT'
      '';
in
delib.module {
  name = "ghostty";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile = {
      "ghostty/config".source = ghosttyConfig;
      "ghostty/shaders/aurora.glsl".source = ghosttyAuroraShader;
    };
  };
}
