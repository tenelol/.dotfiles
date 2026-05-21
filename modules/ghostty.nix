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
  mkGhosttyReadabilityShader =
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
  mkGhosttyLeafBurstShader =
    myconfig:
    pkgs.writeText "ghostty-leaf-burst.glsl" ''
      const float LEAF_ALPHA = ${toString myconfig.theme.ghostty.leafBurst};
      const float DURATION = 0.95;
      const int LEAF_COUNT = 7;

      vec3 sRGBToLinear(vec3 c) {
          return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
      }

      float hash(float n) {
          return fract(sin(n) * 43758.5453123);
      }

      mat2 rotate2d(float a) {
          float s = sin(a);
          float c = cos(a);
          return mat2(c, -s, s, c);
      }

      vec2 normalizeToScreen(vec2 value, float isPosition) {
          return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
      }

      float leafBody(vec2 p) {
          float taper = clamp(1.0 - abs(p.y) * 0.82, 0.18, 1.0);
          float body = length(vec2(p.x / (0.34 * taper), p.y / 0.82));
          return 1.0 - smoothstep(0.96, 1.05, body);
      }

      float leafVein(vec2 p) {
          float mainVein = 1.0 - smoothstep(0.008, 0.024, abs(p.x));
          float lengthMask = smoothstep(-0.70, -0.18, p.y) * (1.0 - smoothstep(0.18, 0.70, p.y));
          float sideA = 1.0 - smoothstep(0.006, 0.020, abs(p.x - p.y * 0.20));
          float sideB = 1.0 - smoothstep(0.006, 0.020, abs(p.x + p.y * 0.20));
          return max(mainVein * lengthMask, max(sideA, sideB) * 0.34 * leafBody(p));
      }

      void mainImage(out vec4 fragColor, in vec2 fragCoord) {
          vec2 uv = fragCoord.xy / iResolution.xy;
          vec4 baseColor = texture(iChannel0, uv);
          fragColor = baseColor;

          if (LEAF_ALPHA <= 0.0 || iFocus == 0) {
              return;
          }

          vec2 p = normalizeToScreen(fragCoord.xy, 1.0);
          vec4 currentCursor = vec4(normalizeToScreen(iCurrentCursor.xy, 1.0), normalizeToScreen(iCurrentCursor.zw, 0.0));
          vec4 previousCursor = vec4(normalizeToScreen(iPreviousCursor.xy, 1.0), normalizeToScreen(iPreviousCursor.zw, 0.0));

          vec2 offsetFactor = vec2(-0.5, 0.5);
          vec2 currentCenter = currentCursor.xy - currentCursor.zw * offsetFactor;
          vec2 previousCenter = previousCursor.xy - previousCursor.zw * offsetFactor;
          vec2 delta = currentCenter - previousCenter;
          float distanceMoved = length(delta);
          float minDistance = currentCursor.w * 0.75;
          float progress = (iTime - iTimeCursorChange) / DURATION;

          if (distanceMoved <= minDistance || progress < 0.0 || progress >= 1.0) {
              return;
          }

          vec2 direction = normalize(delta + vec2(0.0001, 0.0001));
          vec2 normal = vec2(-direction.y, direction.x);
          vec3 leafDark = sRGBToLinear(vec3(0.10, 0.46, 0.20));
          vec3 leafLight = sRGBToLinear(vec3(0.52, 0.92, 0.42));

          for (int i = 0; i < LEAF_COUNT; i++) {
              float fi = float(i);
              float seed = fi * 19.73 + 4.21;
              float delay = hash(seed) * 0.30;
              float t = clamp((progress - delay) / (1.0 - delay), 0.0, 1.0);
              float active = step(0.001, t) * (1.0 - step(1.0, t));
              float flutter = sin(iTime * (5.2 + hash(seed + 1.0) * 3.0) + seed);
              float side = (hash(seed + 2.0) - 0.5) * 0.20;

              vec2 origin = mix(previousCenter, currentCenter, 0.35 + hash(seed + 3.0) * 0.55);
              vec2 drift = normal * (side + flutter * 0.025 * t) - direction * (0.05 + hash(seed + 4.0) * 0.09) * t;
              drift += vec2(0.025 * sin(t * 8.0 + seed), -0.15 * t * t);
              vec2 leafPosition = origin + drift;

              float size = mix(0.030, 0.052, hash(seed + 5.0));
              float angle = atan(direction.y, direction.x) + 1.57079632679 + flutter * 0.55 + (hash(seed + 6.0) - 0.5) * 1.6;
              vec2 local = rotate2d(-angle) * (p - leafPosition) / size;
              float body = leafBody(local);
              float vein = leafVein(local);
              float fade = pow(1.0 - t, 1.25) * smoothstep(0.0, 0.16, t);
              float alpha = body * fade * active * LEAF_ALPHA;
              vec3 leafColor = mix(leafDark, leafLight, hash(seed + 7.0));
              leafColor = mix(leafColor, sRGBToLinear(vec3(0.86, 1.0, 0.66)), vein * 0.45);

              fragColor.rgb = mix(fragColor.rgb, leafColor, alpha);
              fragColor.a = max(fragColor.a, alpha);
          }
      }
    '';
  mkGhosttyConfig =
    myconfig:
    let
      theme = myconfig.theme.ghostty;
    in
    pkgs.writeText "ghostty-config" (
      builtins.replaceStrings
        [
          "foreground = c0caf5"
          "background = 24283b"
          "background-blur = 96"
          "background-blur = 64"
          "cursor-color = 7aa2f7"
          "selection-foreground = c0caf5"
          "selection-background = 364a82"
          "palette = 4=7aa2f7"
          "palette = 6=7dcfff"
          "palette = 12=7aa2f7"
          "palette = 14=8be9ff"
        ]
        [
          "foreground = ${theme.foreground}"
          "background = ${theme.background}"
          "background-blur = ${toString theme.backgroundBlur}"
          "background-blur = ${toString theme.backgroundBlur}"
          "cursor-color = ${theme.cursor}"
          "selection-foreground = ${theme.selectionForeground}"
          "selection-background = ${theme.selectionBackground}"
          "palette = 4=${theme.paletteBlue}"
          "palette = 6=${theme.paletteCyan}"
          "palette = 12=${theme.paletteBrightBlue}"
          "palette = 14=${theme.paletteBrightCyan}"
        ]
        (builtins.readFile ghosttyConfig)
    );
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
  ghosttyRippleRectangleCursorShader =
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
delib.module {
  name = "ghostty";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled =
    { myconfig, ... }:
    {
      xdg.configFile = {
        "ghostty/config".source = mkGhosttyConfig myconfig;
        "ghostty/shaders/aurora.glsl".source = ghosttyAuroraShader;
        "ghostty/shaders/liquid_glass_focus.glsl".source =
          ../config/ghostty/shaders/liquid_glass_focus.glsl;
        "ghostty/shaders/readability_scrim.glsl".source = mkGhosttyReadabilityShader myconfig;
        "ghostty/shaders/cursor_tail.glsl".source = ghosttyCursorTailShader;
        "ghostty/shaders/leaf_burst.glsl".source = mkGhosttyLeafBurstShader myconfig;
        "ghostty/shaders/ripple_rectangle_cursor.glsl".source = ghosttyRippleRectangleCursorShader;
      };
    };
}
