{ delib, ... }:
delib.host {
  name = "macbook";
  type = "laptop";
  system = "aarch64-darwin";

  myconfig.nixbuild.enable = true;

  rice = "rift";
}
