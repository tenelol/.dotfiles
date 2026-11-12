{ delib, ... }:
delib.host {
  name = "macbook";
  type = "laptop";
  system = "aarch64-darwin";
  features = [ "fullDesktop" ];

  rice = "rift";

  myconfig = {
    nixbuild.enable = true;
    codex-notion-token.enable = false;
  };
}
