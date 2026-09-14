{
  delib,
  host,
  lib,
  ...
}:
let
  isMacbook = host.name == "macbook" && builtins.match ".*-darwin" host.system != null;
in
delib.module {
  name = "pi-coding-agent";

  options = delib.singleEnableOption isMacbook;

  home.ifEnabled = lib.mkIf isMacbook {
    # Evaluate Home Manager's file helpers in its own module scope.
    imports = [
      (
        { config, ... }:
        let
          sourceRoot = "${config.home.homeDirectory}/.dotfiles/modules/pi-coding-agent/files";
          editableSource = relative: {
            source = config.lib.file.mkOutOfStoreSymlink "${sourceRoot}/${relative}";
            force = true;
          };
          extensions = lib.filterAttrs (_: type: type == "directory") (
            builtins.readDir ./files/extensions
          );
          extensionFiles = lib.mapAttrs' (
            name: _:
            lib.nameValuePair ".pi/agent/extensions/${name}" (editableSource "extensions/${name}")
          ) extensions;
          prompts = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (
            builtins.readDir ./files/extensions/pi-subagents/prompts
          );
          promptFiles = lib.mapAttrs' (
            name: _:
            lib.nameValuePair ".pi/agent/prompts/${name}" (
              editableSource "extensions/pi-subagents/prompts/${name}"
            )
          ) prompts;
        in
        {
          home.file = extensionFiles // promptFiles // {
            ".pi/agent/settings.json" = {
              source = ./files/settings.json;
              force = true;
            };
            ".pi/agent/models.json".source = ./files/models.json;
            ".pi/agent/extensions/playwright-cli" = editableSource "tools/playwright-cli";
            ".pi/agent/extensions/dashboard-header" = editableSource "hooks/dashboard";
            ".pi/agent/themes/tokyonight-muted.json" = editableSource "hooks/dashboard/themes/tokyonight-muted.json";
            ".pi/agent/AGENTS.md" = {
              source = ./files/AGENTS.md;
              force = true;
            };
            ".pi/agent/project-context-protocol.md" = {
              source = ../vault-context/files/codex/project-context-protocol.md;
              force = true;
            };
            ".pi/agent/references/delegation.md" = {
              source = ./files/references/delegation.md;
              force = true;
            };
          };
        }
      )
    ];
  };
}
