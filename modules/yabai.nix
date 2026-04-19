{
  delib,
  host,
  pkgs,
  profile,
  ...
}:
let
  homeDir = "/Users/${profile.username}";
in
delib.module {
  name = "yabai";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    services.yabai = {
      enable = true;
      package = pkgs.yabai;

      # Space focus and moving windows between spaces require yabai's scripting
      # addition on recent macOS versions. This also installs the matching
      # sudoers rule for loading it without a password.
      enableScriptingAddition = true;

      config = {
        layout = "bsp";
        split_type = "auto";
        window_placement = "second_child";
        window_insertion_point = "focused";

        mouse_follows_focus = "off";
        focus_follows_mouse = "off";
        window_origin_display = "default";
        window_zoom_persist = "on";

        top_padding = 0;
        bottom_padding = 0;
        left_padding = 0;
        right_padding = 0;
        window_gap = 0;
        external_bar = "all:42:0";

        mouse_modifier = "alt";
        mouse_action1 = "move";
        mouse_action2 = "resize";
        mouse_drop_action = "swap";
      };

      extraConfig = ''
        yabai -m signal --remove yabai_load_sa 2>/dev/null || true
        yabai -m signal --add label=yabai_load_sa event=dock_did_restart action='sudo ${pkgs.yabai}/bin/yabai --load-sa'
        sudo ${pkgs.yabai}/bin/yabai --load-sa 2>/dev/null || true

        for sid in 1 2 3 4 5 6 7 8 9; do
          yabai -m space "$sid" --label "$sid" 2>/dev/null || true
        done

        for rule in system_settings system_preferences app_store calculator finder_dialogs; do
          yabai -m rule --remove "$rule" 2>/dev/null || true
        done

        yabai -m rule --add label=system_settings app='System Settings' manage=off
        yabai -m rule --add label=system_preferences app='System Preferences' manage=off
        yabai -m rule --add label=app_store app='App Store' manage=off
        yabai -m rule --add label=calculator app='Calculator' manage=off
        yabai -m rule --add label=finder_dialogs app='Finder' title='^(Copy|Move|Info|Preferences)' manage=off

        for signal in sketchybar_space_changed sketchybar_display_changed sketchybar_space_created sketchybar_space_destroyed; do
          yabai -m signal --remove "$signal" 2>/dev/null || true
        done

        yabai -m signal --add label=sketchybar_space_changed event=space_changed action='/opt/homebrew/bin/sketchybar --trigger yabai_space_change FOCUSED=$YABAI_SPACE_INDEX'
        yabai -m signal --add label=sketchybar_display_changed event=display_changed action='/opt/homebrew/bin/sketchybar --trigger yabai_space_change'
        yabai -m signal --add label=sketchybar_space_created event=space_created action='/opt/homebrew/bin/sketchybar --reload'
        yabai -m signal --add label=sketchybar_space_destroyed event=space_destroyed action='/opt/homebrew/bin/sketchybar --reload'

        /opt/homebrew/bin/sketchybar --trigger yabai_space_change 2>/dev/null || true
      '';
    };

    services.skhd = {
      enable = true;
      package = pkgs.skhd;
      skhdConfig = builtins.readFile ../config/yabai/skhdrc;
    };

    launchd.user.agents.yabai.serviceConfig.EnvironmentVariables = {
      USER = profile.username;
      HOME = homeDir;
    };

    launchd.user.agents.skhd.serviceConfig.EnvironmentVariables = {
      USER = profile.username;
      HOME = homeDir;
    };

    system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
      # Disable Spotlight's native shortcuts so they do not conflict with
      # launcher bindings managed elsewhere.
      "64" = {
        enabled = false;
        value = {
          type = "standard";
          parameters = [
            32
            49
            1048576
          ];
        };
      };
      "65" = {
        enabled = false;
        value = {
          type = "standard";
          parameters = [
            32
            49
            1572864
          ];
        };
      };

      # Keep Mission Control's Ctrl+1..9 desktop shortcuts enabled as a native
      # fallback for manual space switching.
      "118" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            49
            18
            262144
          ];
        };
      };
      "119" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            50
            19
            262144
          ];
        };
      };
      "120" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            51
            20
            262144
          ];
        };
      };
      "121" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            52
            21
            262144
          ];
        };
      };
      "122" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            53
            23
            262144
          ];
        };
      };
      "123" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            54
            22
            262144
          ];
        };
      };
      "124" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            55
            26
            262144
          ];
        };
      };
      "125" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            56
            28
            262144
          ];
        };
      };
      "126" = {
        enabled = true;
        value = {
          type = "standard";
          parameters = [
            57
            25
            262144
          ];
        };
      };
    };
  };

  home.ifEnabled = {
    xdg.configFile."yabai/skhdrc".source = ../config/yabai/skhdrc;
  };
}
