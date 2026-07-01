{
  delib,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
let
  macbook = import ../lib/darwin/macbook.nix { inherit lib pkgs profile; };
in
delib.module {
  name = "darwin.host.macbook";

  options = delib.singleEnableOption (host.name == "macbook");

  darwin.ifEnabled = {
    networking.computerName = "macbook";
    networking.hostName = "macbook";
    networking.localHostName = "macbook";

    environment.systemPackages = macbook.systemPackages;

    system.defaults = macbook.defaults;
    system.keyboard = macbook.keyboard;
    system.activationScripts = macbook.activationScripts;
  };
}
