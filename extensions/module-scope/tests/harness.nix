let
  lock = builtins.fromJSON (builtins.readFile ../../../flake.lock);
  source =
    name:
    let
      locked = lock.nodes.${name}.locked;
    in
    (builtins.fetchTree {
      inherit (locked)
        type
        owner
        repo
        rev
        narHash
        ;
    }).outPath;
  lib = import (source "nixpkgs-lib" + "/lib");
  denixSource = source "denix";
  base = import (denixSource + "/lib") {
    inherit lib;
    nixpkgs = { };
    home-manager = { };
    nix-darwin = { };
  };
  mkDelib =
    moduleSystem:
    (base.recursivelyExtend (
      final: prev: {
        inherit
          (import (denixSource + "/lib/configurations/module.nix") {
            inherit lib;
            delib = final;
            myconfigName = "myconfig";
            apply = import (denixSource + "/lib/configurations/apply.nix") {
              inherit moduleSystem;
              myconfigName = "myconfig";
              homeManagerUser = "probe";
              useHomeManagerModule = true;
            };
          })
          module
          ;
      }
    )).withExtensions
      [ (base.callExtension ../default.nix) ];
  probeOption = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
  };
  schema = {
    options.probe = probeOption;
    options.home-manager.users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submoduleWith {
          modules = [ { options.probe = probeOption; } ];
        }
      );
      default = { };
    };
  };
in
{
  inherit
    lib
    base
    mkDelib
    schema
    ;
}
