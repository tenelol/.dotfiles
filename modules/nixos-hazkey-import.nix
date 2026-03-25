{ delib, inputs, ... }:
delib.module {
  name = "nixos.hazkey-import";

  nixos.always = {
    imports = [ inputs.nix-hazkey.nixosModules.hazkey ];
  };
}
