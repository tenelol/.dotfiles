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
      ".config/raycast/lib/workspace.sh" = {
        source = ../config/raycast/lib/workspace.sh;
        executable = true;
      };

      ".config/raycast/scripts/dotfiles-rebuild-macbook.sh" = {
        source = ../config/raycast/scripts/dotfiles-rebuild-macbook.sh;
        executable = true;
      };

      ".config/raycast/scripts/open-ghostty.sh" = {
        source = ../config/raycast/scripts/open-ghostty.sh;
        executable = true;
      };

      ".config/raycast/scripts/workspace-coding.sh" = {
        source = ../config/raycast/scripts/workspace-coding.sh;
        executable = true;
      };

      ".config/raycast/scripts/workspace-communication.sh" = {
        source = ../config/raycast/scripts/workspace-communication.sh;
        executable = true;
      };

      ".config/raycast/scripts/workspace-assistants.sh" = {
        source = ../config/raycast/scripts/workspace-assistants.sh;
        executable = true;
      };
    };
  };
}
