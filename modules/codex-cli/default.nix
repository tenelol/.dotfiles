{
  delib,
  hostTraits,
  ...
}:
delib.module {
  name = "codex-cli";

  options = delib.singleEnableOption hostTraits.macbook;

  home.ifEnabled = {
    home.file.".codex/themes/tokyonight-muted.tmTheme" = {
      source = ./files/tokyonight-muted.tmTheme;
      force = true;
    };
  };
}
