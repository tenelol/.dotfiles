{
  delib,
  hostTraits,
  hm,
  lib,
  pkgs,
  ...
}:
let
  baseConfig =
    if pkgs.stdenv.hostPlatform.isDarwin then ./files/config-darwin else ./files/config;

  # Cursor and focus effects share hud_common.glsl; Ghostty has no includes.
  mkHudShader =
    name:
    pkgs.writeText "ghostty-${name}" (
      builtins.readFile ./files/shaders/hud_common.glsl + "\n" + builtins.readFile ./files/shaders/${name}
    );

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

  themedConfigText =
    myconfig:
    let
      theme = myconfig.theme.ghostty;
    in
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
      (builtins.readFile baseConfig);

  # With myconfig.theme.colors = "omniwm" the colors move out of the config:
  # OmniWM App Theming writes them to themes/omniwm-{light,dark} and reloads
  # Ghostty. A color set in the config itself would override the theme, so
  # every color line is replaced by one theme reference.
  omniwmThemeLine = "theme = light:omniwm-light,dark:omniwm-dark";
  colorKeys = [
    "foreground"
    "background"
    "cursor-color"
    "selection-foreground"
    "selection-background"
    "palette"
  ];
  isColorLine = line: lib.any (key: lib.hasPrefix "${key} = " line) colorKeys;
  configLines = myconfig: lib.splitString "\n" (themedConfigText myconfig);

  mkConfig =
    myconfig:
    pkgs.writeText "ghostty-config" (
      if myconfig.theme.colors == "omniwm" then
        lib.concatStringsSep "\n" (
          lib.concatMap (
            line:
            if lib.hasPrefix "foreground = " line then
              [ omniwmThemeLine ]
            else if isColorLine line || lib.hasPrefix "theme = " line then
              [ ]
            else
              [ line ]
          ) (configLines myconfig)
        )
      else
        themedConfigText myconfig
    );

  # The static palette, in Ghostty's theme format. It stands in for both OmniWM
  # themes until App Theming is turned on, so the theme reference above never
  # points at a missing file.
  mkSeedTheme =
    myconfig:
    pkgs.writeText "ghostty-omniwm-seed-theme" (
      lib.concatStringsSep "\n" (lib.filter isColorLine (configLines myconfig)) + "\n"
    );

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

in
delib.module {
  name = "ghostty";

  options = delib.singleEnableOption hostTraits.desktop;

  home.ifEnabled =
    { myconfig, ... }:
    {
      xdg.configFile = {
        "ghostty/config".source = mkConfig myconfig;
        "ghostty/shaders/aurora.glsl".source = auroraShader;
        "ghostty/shaders/focus_ripple.glsl".source = mkHudShader "focus_ripple.glsl";
        "ghostty/shaders/readability_scrim.glsl".source = mkReadabilityShader myconfig;
        "ghostty/shaders/cursor_smear.glsl".source = mkHudShader "cursor_smear.glsl";
        "ghostty/shaders/typing_ignite.glsl".source = mkHudShader "typing_ignite.glsl";
        "ghostty/shaders/typing_ripple.glsl".source = mkHudShader "typing_ripple.glsl";
        "ghostty/shaders/jump_lockon.glsl".source = mkHudShader "jump_lockon.glsl";
        "ghostty/shaders/font_zoom.glsl".source = mkHudShader "font_zoom.glsl";
      };

      # Regular files, not store links: OmniWM replaces them once App Theming is
      # on, and only writes inside the home folder.
      home.activation.seedGhosttyOmniwmThemes = lib.mkIf (myconfig.theme.colors == "omniwm") (
        hm.dag.entryAfter [ "linkGeneration" ] ''
          for name in omniwm-light omniwm-dark; do
            target="$HOME/.config/ghostty/themes/$name"
            if [ ! -e "$target" ]; then
              $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -D -m 0644 ${mkSeedTheme myconfig} "$target"
            fi
          done
        ''
      );
    };
}
