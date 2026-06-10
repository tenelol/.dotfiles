{ delib, ... }:
delib.host {
  name = "wsl";
  type = "server";
  system = "x86_64-linux";

  rice = "indigo";
}
