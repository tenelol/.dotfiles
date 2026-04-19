{
  delib,
  host,
  ...
}:
delib.module {
  name = "raycast";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  home.ifEnabled = {
    home.file = {
      ".config/raycast/scripts/dotfiles-rebuild-macbook.sh" = {
        source = ../config/raycast/scripts/dotfiles-rebuild-macbook.sh;
        executable = true;
      };

      ".config/raycast/scripts/open-ghostty.sh" = {
        source = ../config/raycast/scripts/open-ghostty.sh;
        executable = true;
      };
    };
  };

  darwin.ifEnabled = {
    system.defaults.CustomUserPreferences."com.raycast.macos" = {
      mainWindow_isMonitoringGlobalHotkeys = false;
      raycastGlobalHotkey = "";
    };
  };
}
