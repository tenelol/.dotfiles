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
  mkGhosttyLeafBurstShader =
    myconfig:
    pkgs.writeText "ghostty-leaf-burst.glsl" ''
      const float LEAF_ALPHA = ${toString myconfig.theme.ghostty.leafBurst};
      const float DURATION = 0.78;
      const int LEAF_COUNT = 9;
      const float MIN_HORIZONTAL_CELLS = 1.35;
      const float MIN_VERTICAL_LINES = 0.45;

      vec3 sRGBToLinear(vec3 c) {
          return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
      }

      float hash(float n) {
          return fract(sin(n) * 43758.5453123);
      }

      mat2 rotate2d(float angle) {
          float s = sin(angle);
          float c = cos(angle);
          return mat2(c, -s, s, c);
      }

      vec2 normalizeToScreen(vec2 value, float isPosition) {
          return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
      }

      float leafSdf(vec2 p) {
          float taper = clamp(1.0 - abs(p.y) * 0.72, 0.24, 1.0);
          return length(vec2(p.x / (0.34 * taper), p.y / 0.82)) - 1.0;
      }

      float leafVein(vec2 p) {
          float body = 1.0 - smoothstep(-0.02, 0.05, leafSdf(p));
          float mainVein = 1.0 - smoothstep(0.012, 0.035, abs(p.x));
          float lengthMask = smoothstep(-0.72, -0.12, p.y) * (1.0 - smoothstep(0.16, 0.72, p.y));
          float sideA = 1.0 - smoothstep(0.010, 0.030, abs(p.x - p.y * 0.22));
          float sideB = 1.0 - smoothstep(0.010, 0.030, abs(p.x + p.y * 0.22));
          return max(mainVein * lengthMask, max(sideA, sideB) * body * 0.32);
      }

      void mainImage(out vec4 fragColor, in vec2 fragCoord) {
          vec2 uv = fragCoord.xy / iResolution.xy;
          fragColor = texture(iChannel0, uv);

          if (LEAF_ALPHA <= 0.0) {
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
          float minMovement = max(currentCursor.z * MIN_HORIZONTAL_CELLS, currentCursor.w * MIN_VERTICAL_LINES);
          float progress = (iTime - iTimeCursorChange) / DURATION;

          if (distanceMoved <= minMovement || progress < 0.0 || progress >= 1.0) {
              return;
          }

          float hasDirection = step(0.0001, distanceMoved);
          vec2 direction = normalize(mix(vec2(0.55, -0.30), delta, hasDirection));
          vec2 normal = vec2(-direction.y, direction.x);
          vec3 leafDark = sRGBToLinear(vec3(0.10, 0.38, 0.16));
          vec3 leafMid = sRGBToLinear(vec3(0.32, 0.74, 0.30));
          vec3 leafLight = sRGBToLinear(vec3(0.76, 1.00, 0.48));

          for (int i = 0; i < LEAF_COUNT; i++) {
              float fi = float(i);
              float seed = fi * 23.17 + 9.31;
              float delay = hash(seed) * 0.22;
              float t = clamp((progress - delay) / (1.0 - delay), 0.0, 1.0);
              float leafActive = step(0.001, t) * (1.0 - step(1.0, t));
              float fade = pow(1.0 - t, 1.10) * smoothstep(0.0, 0.10, t) * leafActive;
              float flutter = sin(iTime * (4.5 + hash(seed + 1.0) * 4.0) + seed);
              float side = (hash(seed + 2.0) - 0.5) * 0.18;

              vec2 anchor = mix(previousCenter, currentCenter, 0.28 + hash(seed + 3.0) * 0.62);
              vec2 drift = normal * (side + flutter * 0.030 * t);
              drift += direction * ((hash(seed + 4.0) - 0.65) * 0.10 * t);
              drift += vec2(0.020 * sin(t * 9.0 + seed), -0.11 * t * t);
              vec2 leafPosition = anchor + drift;

              float size = mix(0.038, 0.065, hash(seed + 5.0));
              float angle = atan(direction.y, direction.x) + 1.57079632679 + flutter * 0.60 + (hash(seed + 6.0) - 0.5) * 1.8;
              vec2 local = rotate2d(-angle) * (p - leafPosition) / size;
              float shape = 1.0 - smoothstep(-0.035, 0.035, leafSdf(local));
              float vein = leafVein(local);
              float alpha = shape * fade * LEAF_ALPHA;
              vec3 leafColor = mix(leafDark, leafMid, hash(seed + 7.0));
              leafColor = mix(leafColor, leafLight, vein * 0.52);

              fragColor.rgb = mix(fragColor.rgb, leafColor, alpha);
              fragColor.a = max(fragColor.a, alpha);
          }
      }
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
