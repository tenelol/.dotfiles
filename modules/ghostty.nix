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
  ghosttyShaderFiles = {
    "cursor_warp.glsl" = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/sahaj-b/ghostty-cursor-shaders/06d4e90fb5410e9c4d0b3131584060adddf89406/cursor_warp.glsl";
      hash = "sha256-WJ9x9TfO6JCgfkCPE9Bi/32T3m2fdCyE5L3mEExdUfs=";
    };
    "bloom.glsl" = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/hackr-sh/ghostty-shaders/aa6121ba2ddd5251ac75b92729c758fe41256e55/bloom.glsl";
      hash = "sha256-9r5suoOrO6EMXJ5d8rKfncQF/OMufVPg1LreC+DDiM8=";
    };
    "aurora.glsl" =
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
    "bettercrt.glsl" =
      pkgs.runCommand "ghostty-bettercrt-preserve-alpha.glsl"
        {
          src = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/hackr-sh/ghostty-shaders/aa6121ba2ddd5251ac75b92729c758fe41256e55/bettercrt.glsl";
            hash = "sha256-MG6HR5iW2Izn2XZqVogsRAU5tNgplHYKurx+jfYdY0I=";
          };
        }
        ''
          substitute "$src" "$out" \
            --replace-fail \
              'fragColor = vec4(mix(color, vec3(0.0), apply), 1.0);' \
              'fragColor = vec4(mix(color, vec3(0.0), apply), texture(iChannel0, uv).a);'
        '';
    "crt.glsl" =
      pkgs.runCommand "ghostty-crt-preserve-alpha.glsl"
        {
          src = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/hackr-sh/ghostty-shaders/aa6121ba2ddd5251ac75b92729c758fe41256e55/crt.glsl";
            hash = "sha256-qWNom5hLIEvzANt7O2bnm+fRdNKGC0LoAOQ5nCAsB90=";
          };
        }
        ''
          substitute "$src" "$out" \
            --replace-fail \
              'fragColor = vec4(ToSrgb(fragColor.rgb), 1.0);' \
              'vec2 uv = fragCoord.xy / iResolution.xy; fragColor = vec4(ToSrgb(fragColor.rgb), texture(iChannel0, uv).a);'
        '';
  };
  ghosttyShaderConfigFiles = pkgs.lib.mapAttrs' (
    name: source: pkgs.lib.nameValuePair "ghostty/shaders/${name}" { inherit source; }
  ) ghosttyShaderFiles;
in
delib.module {
  name = "ghostty";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile = {
      "ghostty/config".source = ghosttyConfig;
    }
    // ghosttyShaderConfigFiles;
  };
}
