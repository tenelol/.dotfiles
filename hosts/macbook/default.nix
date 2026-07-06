{ delib, ... }:
delib.host {
  name = "macbook";
  type = "laptop";
  system = "aarch64-darwin";

  myconfig.nixbuild.enable = true;
  myconfig.karabiner.enable = true;

  rice = "rift";
}
