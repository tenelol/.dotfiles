{ pkgs }:
let
  baseConfig =
    if pkgs.stdenv.hostPlatform.isDarwin then
      ../config/ghostty/config-darwin
    else
      ../config/ghostty/config;

  mkReadabilityShader =
    myconfig:
    pkgs.writeText "ghostty-readability-scrim.glsl" ''
      const float SCRIM_ALPHA = ${toString myconfig.theme.ghostty.readabilityScrim};

      void mainImage(out vec4 fragColor, in vec2 fragCoord) {
          vec2 uv = fragCoord.xy / iResolution.xy;
          vec4 baseColor = texture(iChannel0, uv);

          if (SCRIM_ALPHA <= 0.0) {
              fragColor = baseColor;
              return;
          }

          float backgroundMask = 1.0 - smoothstep(0.02, 0.18, baseColor.a);
          float scrimAlpha = SCRIM_ALPHA * backgroundMask;
          vec3 scrimColor = iBackgroundColor * 0.55;
          vec3 color = mix(baseColor.rgb, scrimColor, scrimAlpha);

          fragColor = vec4(color, max(baseColor.a, scrimAlpha));
      }
    '';

  mkConfig =
    myconfig:
    let
      theme = myconfig.theme.ghostty;
      config = builtins.readFile baseConfig;
      themedConfig =
        builtins.replaceStrings
          [
            "foreground = c0caf5"
            "background = 24283b"
            "background-blur = 96"
            "background-blur = 64"
            "cursor-color = 7aa2f7"
            "selection-foreground = c0caf5"
            "selection-background = 364a82"
          ]
          [
            "foreground = ${theme.foreground}"
            "background = ${theme.background}"
            "background-blur = ${toString theme.backgroundBlur}"
            "background-blur = ${toString theme.backgroundBlur}"
            "cursor-color = ${theme.cursor}"
            "selection-foreground = ${theme.selectionForeground}"
            "selection-background = ${theme.selectionBackground}"
          ]
          config;
    in
    pkgs.writeText "ghostty-config" themedConfig;

  auroraShader =
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

  cursorTailShader =
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

  rippleRectangleCursorShader =
    pkgs.runCommand "ghostty-ripple-rectangle-cursor-subtle.glsl"
      {
        src = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/sahaj-b/ghostty-cursor-shaders/06d4e90fb5410e9c4d0b3131584060adddf89406/ripple_rectangle_cursor.glsl";
          hash = "sha256-KnrJqjKjyxNku33b2eYHCSquwKzibVsPO8pB5xxugMg=";
        };
      }
      ''
        cp "$src" "$out"
        substituteInPlace "$out" \
          --replace-fail 'const float MAX_SIZE = 0.05;' 'const float MAX_SIZE = 0.034;' \
          --replace-fail 'const float RING_THICKNESS = 0.02;' 'const float RING_THICKNESS = 0.018;' \
          --replace-fail 'vec4 COLOR = vec4(0.35, 0.36, 0.44, 1.0);' 'vec4 COLOR = vec4(0.35, 0.36, 0.44, 0.68);' \
          --replace-fail 'const float BLUR = 1.0;' 'const float BLUR = 1.2;'
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
{
  inherit mkConfig mkReadabilityShader;

  shaders = {
    aurora = auroraShader;
    liquidGlassFocus = ../config/ghostty/shaders/liquid_glass_focus.glsl;
    readabilityScrim = mkReadabilityShader;
    cursorTail = cursorTailShader;
    rippleRectangleCursor = rippleRectangleCursorShader;
  };
}
