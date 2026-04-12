{
  delib,
  host,
  pkgs,
  ...
}:
delib.module {
  name = "yabai";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    services.yabai = {
      enable = true;
      package = pkgs.yabai;

      # Keep SIP-dependent features opt-in. Space switching and moving windows
      # between spaces may need the scripting addition on recent macOS versions.
      enableScriptingAddition = false;

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
  };

  home.ifEnabled = {
    xdg.configFile."yabai/skhdrc".source = ../config/yabai/skhdrc;
  };
}
