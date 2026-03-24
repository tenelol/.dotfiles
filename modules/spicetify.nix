{
  delib,
  host,
  hostLib,
  inputs,
  pkgs,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
delib.module {
  name = "spicetify";

  options = delib.singleEnableOption (hostLib.isLinuxDesktop host);

  home.ifEnabled = {
    programs.spicetify = {
      enable = true;
      enabledExtensions = with spicePkgs.extensions; [
        adblockify
        hidePodcasts
        shuffle
      ];
      enabledCustomApps = with spicePkgs.apps; [
        lyricsPlus
      ];
      theme = {
        name = "appletify";
        src =
          (pkgs.fetchFromGitHub {
            owner = "raysin1";
            repo = "Appletify";
            rev = "cdd14682d5b7e8c7d108c0caf5a1a7476cd0dd3d";
            hash = "sha256-CEpNThqEXma45jn+ZL19vEZ2mOERB87qOyfVGRaUBZA=";
          })
          + /appletify;
        additionalCss = ''
          [data-testid="lyrics-button"],
          button[aria-label="Lyrics"] {
            display: inline-flex !important;
          }
        '';
      };
      colorScheme = "Base";
    };
  };
}
