{
  delib,
  hostTraits,
  ...
}:
delib.scopedModule {
  name = "codex-cli";
  scope = hostTraits.macbook;

  options = delib.singleEnableOption hostTraits.macbook;

  home.ifEnabled = {
    home.file.".codex/themes/tokyonight-muted.tmTheme" = {
      source = ./files/tokyonight-muted.tmTheme;
      force = true;
    };
  };
}
