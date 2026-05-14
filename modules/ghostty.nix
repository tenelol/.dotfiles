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
          --replace-fail '#define ACTIVE_THEME THEME_AURORA' '#define ACTIVE_THEME THEME_TOKYO_NIGHT' \
          --replace-fail 'const float GLOW_OPACITY = 1.0;' 'const float GLOW_OPACITY = 0.45;' \
          --replace-fail 'fragColor = vec4(finalColor, terminalColor.a);' 'fragColor = vec4(finalColor, max(terminalColor.a, finalSnakeAlpha * GLOW_OPACITY));'
      '';
  ghosttyCursorTailShader =
    pkgs.runCommand "ghostty-cursor-tail-subtle.glsl"
      {
        src = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/sahaj-b/ghostty-cursor-shaders/06d4e90fb5410e9c4d0b3131584060adddf89406/cursor_tail.glsl";
          hash = "sha256-CEEjiRG9USeW8i9c+FbFgt8Rzcrc11KFNHOfvH0soxI=";
        };
      }
      ''
        substitute "$src" "$out" \
          --replace-fail 'vec4 TRAIL_COLOR = vec4(sRGBToLinear(iCurrentCursorColor.rgb), iCurrentCursorColor.a);' 'vec4 TRAIL_COLOR = vec4(sRGBToLinear(iCurrentCursorColor.rgb), iCurrentCursorColor.a * 0.55);' \
          --replace-fail 'const float DURATION = 0.09;' 'const float DURATION = 0.13;' \
          --replace-fail 'const float THRESHOLD_MIN_DISTANCE = 1.5;' 'const float THRESHOLD_MIN_DISTANCE = 1.0;'
      '';
  ghosttyRippleCursorShader =
    pkgs.runCommand "ghostty-ripple-cursor-subtle.glsl"
      {
        src = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/sahaj-b/ghostty-cursor-shaders/06d4e90fb5410e9c4d0b3131584060adddf89406/ripple_cursor.glsl";
          hash = "sha256-QQhm2WeC3AfHDPMcWLh0DMItug54F/6+7fcW3sTYuIQ=";
        };
      }
      ''
        cp "$src" "$out"
        substituteInPlace "$out" \
          --replace-fail 'const float MAX_RADIUS = 0.05;' 'const float MAX_RADIUS = 0.026;' \
          --replace-fail 'const float RING_THICKNESS = 0.02;' 'const float RING_THICKNESS = 0.014;' \
          --replace-fail 'vec4 COLOR = vec4(0.35, 0.36, 0.44, 1.0);' 'vec4 COLOR = vec4(0.35, 0.36, 0.44, 0.45);' \
          --replace-fail 'const float BLUR = 3.0;' 'const float BLUR = 3.5;'
        awk '
          /^    \/\/ Normalization & setup \(-1 to 1 coords\)/ {
            print "    if (iFocus == 0) {";
            print "        return;";
            print "    }";
            print "";
          }
          { print }
        ' "$out" > "$out.tmp"
        mv "$out.tmp" "$out"
      '';
in
delib.module {
  name = "ghostty";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile = {
      "ghostty/config".source = ghosttyConfig;
      "ghostty/shaders/aurora.glsl".source = ghosttyAuroraShader;
      "ghostty/shaders/cursor_tail.glsl".source = ghosttyCursorTailShader;
      "ghostty/shaders/ripple_cursor.glsl".source = ghosttyRippleCursorShader;
    };
  };
}
