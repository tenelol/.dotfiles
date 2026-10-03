{ delib, lib, ... }:
delib.extension {
  name = "module-scope";

  libExtension = _: final: prev: {
    # Keep options declared on every host; scope only gates configuration
    # contributions, including always and disabled cleanup.
    scopedModule =
      { scope, ... }@args:
      let
        gate =
          condition: body:
          if builtins.isFunction body then
            callbackArgs: lib.mkIf condition (body callbackArgs)
          else
            lib.mkIf condition body;
        scopeFor = target: if builtins.isAttrs scope then scope.${target} or true else scope;
      in
      prev.module (
        builtins.removeAttrs args [ "scope" ]
        // lib.genAttrs [ "myconfig" "nixos" "home" "darwin" ] (
          target: lib.mapAttrs (_: gate (scopeFor target)) (args.${target} or { })
        )
      );
  };
}
