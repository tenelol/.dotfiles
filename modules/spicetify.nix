{
  delib,
  hm,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  appletifyTheme =
    (pkgs.fetchFromGitHub {
      owner = "raysin1";
      repo = "Appletify";
      rev = "cdd14682d5b7e8c7d108c0caf5a1a7476cd0dd3d";
      hash = "sha256-CEpNThqEXma45jn+ZL19vEZ2mOERB87qOyfVGRaUBZA=";
    })
    + /appletify;
  appletifyThemeWithLyricsButton = pkgs.runCommand "spicetify-appletify-theme" { } ''
    cp -R ${appletifyTheme} "$out"
    chmod -R u+w "$out"
    cat >> "$out/user.css" <<'CSS'
    [data-testid="lyrics-button"],
    button[aria-label="Lyrics"] {
      display: inline-flex !important;
    }
    CSS
  '';
  extensions = with spicePkgs.extensions; [
    adblockify
    hidePodcasts
    shuffle
  ];
  lyricsPlus = spicePkgs.apps.lyricsPlus;
in
delib.module {
  name = "spicetify";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = lib.mkMerge [
    (lib.mkIf (!isDarwin) {
      programs.spicetify = {
        enable = true;
        enabledExtensions = extensions;
        enabledCustomApps = [
          lyricsPlus
        ];
        theme = {
          name = "appletify";
          src = appletifyTheme;
          additionalCss = ''
            [data-testid="lyrics-button"],
            button[aria-label="Lyrics"] {
              display: inline-flex !important;
            }
          '';
        };
        colorScheme = "Base";
      };
    })

    (lib.mkIf isDarwin {
      home.packages = [
        pkgs.spicetify-cli
      ];

      home.file =
        (lib.listToAttrs (
          map (extension: {
            name = ".config/spicetify/Extensions/${extension.name}";
            value.source = "${extension.src}/${extension.name}";
          }) extensions
        ))
        // {
          ".config/spicetify/CustomApps/${lyricsPlus.name}".source = lyricsPlus.src;
          ".config/spicetify/Themes/appletify".source = appletifyThemeWithLyricsButton;
        };

      home.activation.applySpicetify = hm.dag.entryAfter [ "linkGeneration" ] ''
        spicetify="${pkgs.spicetify-cli}/bin/spicetify"
        spotify_app="/Applications/Spotify.app"
        spotify_resources="$spotify_app/Contents/Resources"

        if [ ! -d "$spotify_resources" ]; then
          echo "Skipping Spicetify: $spotify_app is not installed."
        else
          if /usr/bin/pgrep -x Spotify >/dev/null 2>&1; then
            /usr/bin/osascript -e 'tell application "Spotify" to quit' >/dev/null 2>&1 || true
            /bin/sleep 2
          fi

          "$spicetify" config \
            spotify_path "$spotify_resources" \
            prefs_path "$HOME/Library/Application Support/Spotify/prefs" \
            current_theme appletify \
            color_scheme Base \
            inject_css 1 \
            replace_colors 1 \
            inject_theme_js 1 \
            check_spicetify_update 0

          "$spicetify" config extensions adblock.js
          "$spicetify" config extensions hidePodcasts.js
          "$spicetify" config extensions 'shuffle+.js'
          "$spicetify" config custom_apps lyrics-plus

          config_file="$HOME/.config/spicetify/config-xpui.ini"
          if [ -f "$config_file" ] && /usr/bin/grep -q '^version = .' "$config_file"; then
            "$spicetify" apply --no-restart || {
              "$spicetify" restore || true
              "$spicetify" backup apply --no-restart
            }
          else
            "$spicetify" backup apply --no-restart
          fi
        fi
      '';
    })
  ];
}
