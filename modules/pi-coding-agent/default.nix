{
  delib,
  hostTraits,
  inputs,
  lib,
  ...
}:
delib.scopedModule {
  name = "pi-coding-agent";
  scope = hostTraits.macbook;

  options = delib.singleEnableOption hostTraits.macbook;

  home.ifEnabled = {
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
          skillCatalog = builtins.fromJSON (builtins.readFile ./files/skill-catalog.json);
          sharedSkillFiles = lib.listToAttrs (
            map (name: lib.nameValuePair ".pi/agent/skills/${name}" {
              source = ../../.agents/skills + "/${name}";
            }) skillCatalog.shared
          );
          piSkills = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./files/skills);
          piSkillFiles = lib.mapAttrs' (
            name: _: lib.nameValuePair ".pi/agent/skills/${name}" {
              source = ./files/skills + "/${name}";
            }
          ) piSkills;
          extensionSkillFiles = lib.mapAttrs' (
            name: relative: lib.nameValuePair ".pi/agent/skills/${name}" {
              source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.pi/agent/${relative}";
            }
          ) skillCatalog.extensions;
        in
        {
          home.file = extensionFiles // promptFiles // sharedSkillFiles // piSkillFiles // extensionSkillFiles // {
            ".dotfiles/.pi/settings.json" = {
              source = ./files/dotfiles-project-settings.json;
              force = true;
            };
            ".pi/agent/settings.json" = {
              source = ./files/settings.json;
              force = true;
            };
            ".pi/agent/keybindings.json".source = ./files/keybindings.json;
            ".pi/agent/zentui.json".source = ./files/zentui.json;
            ".pi/agent/models.json".source = ./files/models.json;
            ".pi/agent/extensions/playwright-cli" = editableSource "tools/playwright-cli";
            ".pi/agent/extensions/computer-use" = editableSource "tools/computer-use";
            ".pi/agent/agents/browser.md".source = ./files/agents/browser.md;
            ".pi/agent/extensions/dashboard-header" = editableSource "hooks/dashboard";
            ".pi/agent/extensions/notify.ts" = editableSource "hooks/notify.ts";
            ".pi/agent/extensions/herdr-agent-state.ts".source =
              "${inputs.herdr}/src/integration/assets/pi/herdr-agent-state.ts";
            ".pi/agent/extensions/herdr-ui.ts" = editableSource "hooks/herdr-ui.ts";
            ".pi/agent/skills/herdr".source = "${inputs.herdr}/skills/herdr";
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
