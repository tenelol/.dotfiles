{ delib, ... }:
delib.host {
  name = "macbook";
  type = "laptop";
  system = "aarch64-darwin";
  features = [ "fullDesktop" ];

  myconfig.nixbuild.enable = true;
  myconfig.karabiner.enable = true;
  myconfig.codex-notion-token.enable = false;

  rice = "rift";
}
