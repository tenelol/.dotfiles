{
  delib,
  hostTraits,
  hm,
  lib,
  pkgs,
  ...
}:
let
  settings = pkgs.writeText "vicinae-settings.json" (
    builtins.toJSON (
      {
        close_on_focus_loss = true;
        pop_to_root_on_close = true;
        launcher_window.compact_mode.enabled = true;
      }
      // lib.optionalAttrs hostTraits.darwinDesktop {
        # Qt maps Control to Command on macOS.
        global_shortcuts.toggle = "control+space";
      }
    )
  );
in
delib.scopedModule {
  name = "vicinae";
  scope = hostTraits.desktop;

  options = delib.singleEnableOption hostTraits.desktop;

  home.ifEnabled =
    lib.optionalAttrs hostTraits.linuxDesktop {
      programs.vicinae = {
        enable = true;
        package = pkgs.vicinae;
        systemd.enable = true;
      };
      # Keep settings.json writable for preferences changed in the app.
      systemd.user.services.vicinae.Service.Environment = [ "VICINAE_OVERRIDES=${settings}" ];
    }
    // lib.optionalAttrs hostTraits.darwinDesktop {
      home.packages = [ pkgs.vicinae ];
      launchd.agents.vicinae = {
        enable = true;
        config = {
          ProgramArguments = [
            "${pkgs.vicinae}/bin/vicinae"
            "server"
          ];
          EnvironmentVariables.VICINAE_OVERRIDES = "${settings}";
          RunAtLoad = true;
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          ProcessType = "Interactive";
        };
      };
      home.activation.vicinaeShortcut = hm.dag.entryBefore [ "setupLaunchAgents" ] ''
        $DRY_RUN_CMD /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 ${
          lib.escapeShellArg (
            lib.generators.toPlist { escape = true; } {
              enabled = false;
              value = {
                type = "standard";
                parameters = [
                  32
                  49
                  1048576
                ];
              };
            }
          )
        }
      '';
    };
}
