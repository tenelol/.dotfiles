{
  delib,
  host,
  lib,
  ...
}:
let
  isMacbook = host.name == "macbook" && builtins.match ".*-darwin" host.system != null;
in
delib.module {
  name = "codex-cli";

  options = delib.singleEnableOption isMacbook;

  home.ifEnabled = lib.mkIf isMacbook {
    home.file.".codex/themes/tokyonight-muted.tmTheme" = {
      source = ./codex-cli/files/tokyonight-muted.tmTheme;
      force = true;
    };
  };
}
