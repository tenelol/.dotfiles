let
  inherit (import ./harness.nix)
    lib
    base
    mkDelib
    schema
    ;
  fixture = delib: default: {
    name = "demo";
    options = delib.moduleOptions (
      {
        payload = delib.strOption "callback";
        observed = delib.strOption "unset";
      }
      // lib.optionalAttrs (default != null) { enable = delib.boolOption default; }
    );
    myconfig.ifEnabled = { cfg, ... }: { demo.observed = cfg.payload; };
    nixos = {
      always.probe.systemAlways = "nixos";
      ifEnabled = { cfg, ... }: { probe.systemEnabled = cfg.payload; };
      ifDisabled.probe.systemDisabled = "disabled";
    };
    darwin = {
      always.probe.systemAlways = "darwin";
      ifEnabled = { cfg, ... }: { probe.systemEnabled = cfg.payload; };
      ifDisabled.probe.systemDisabled = "disabled";
    };
    home = {
      always.probe.homeAlways = "home";
      ifEnabled = { cfg, ... }: { probe.homeEnabled = cfg.payload; };
      ifDisabled.probe.homeDisabled = "disabled";
    };
  };
  checkScope =
    system: default: override: scope:
    let
      delib = mkDelib system;
      result = lib.evalModules {
        modules = [
          schema
          (delib.scopedModule (fixture delib default // { inherit scope; }))
        ]
        ++ lib.optional (override != null) { myconfig.demo.enable = override; };
      };
      enabled = if override == null then default else override;
      cfg = result.config;
      expectedSystem = lib.optionalAttrs scope (
        {
          systemAlways = system;
        }
        // lib.optionalAttrs (enabled == true) { systemEnabled = "callback"; }
        // lib.optionalAttrs (enabled == false) { systemDisabled = "disabled"; }
      );
      expectedHome = lib.optionalAttrs scope (
        {
          homeAlways = "home";
        }
        // lib.optionalAttrs (enabled == true) { homeEnabled = "callback"; }
        // lib.optionalAttrs (enabled == false) { homeDisabled = "disabled"; }
      );
    in
    assert cfg.probe == expectedSystem;
    assert (cfg.home-manager.users.probe.probe or { }) == expectedHome;
    assert cfg.myconfig.demo.observed == (if scope && enabled == true then "callback" else "unset");
    assert result.options.myconfig.demo.payload.default == "callback";
    true;
  matrix =
    lib.concatMap
      (
        system:
        lib.concatMap
          (
            default:
            lib.concatMap
              (
                override:
                map (scope: checkScope system default override scope) [
                  true
                  false
                ]
              )
              (
                if default == null then
                  [ null ]
                else
                  [
                    null
                    true
                    false
                  ]
              )
          )
          [
            true
            false
            null
          ]
      )
      [
        "nixos"
        "darwin"
      ];
  perTargetScope =
    let
      delib = mkDelib "darwin";
      cfg =
        (lib.evalModules {
          modules = [
            schema
            (delib.scopedModule (
              fixture delib false
              // {
                scope = {
                  home = false;
                };
              }
            ))
          ];
        }).config;
    in
    assert
      cfg.probe == {
        systemAlways = "darwin";
        systemDisabled = "disabled";
      };
    assert (cfg.home-manager.users.probe.probe or { }) == { };
    true;
  argsInjection =
    let
      delib = mkDelib "nixos";
      cfg =
        (lib.evalModules {
          specialArgs = {
            inherit delib;
            host = {
              name = "surface";
              system = "x86_64-linux";
              isServer = false;
            };
          };
          modules = [
            schema
            ../../../modules/host-policy
            (
              { hostTraits, ... }:
              delib.scopedModule {
                name = "consumer";
                scope = hostTraits.linuxDesktop;
                nixos.always.probe.injected = "host-traits";
              }
            )
          ]
          ++ base.extensions.args.modules;
        }).config;
    in
    assert cfg.probe.injected == "host-traits";
    assert cfg.myconfig.args.shared.hostTraits.linuxDesktop;
    assert !cfg.myconfig.args.shared.hostTraits.darwinDesktop;
    true;
in
assert builtins.all (passed: passed) matrix;
assert perTargetScope && argsInjection;
{
  scopeCases = builtins.length matrix;
  perTargetScope = "passed";
  argsInjection = "passed";
}
