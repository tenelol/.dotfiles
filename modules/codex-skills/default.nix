{
  delib,
  host,
  lib,
  ...
}:
let
  isMacbook = host.name == "macbook" && builtins.match ".*-darwin" host.system != null;
  skillRoot = ../../.agents/skills;
  skills = lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillRoot);
  repositorySkills = lib.mapAttrs' (
    name: _:
    lib.nameValuePair ".agents/skills/${name}" {
      # Link each skill atomically so existing agent symlinks cannot redirect
      # recursive Home Manager writes back into the repository source.
      source = skillRoot + "/${name}";
      force = true;
    }
  ) skills;
  packageSkillTargets = {
    council-mode = ".pi/agent/npm/node_modules/pi-subagents/skills/council-mode";
    pi-subagents = ".pi/agent/npm/node_modules/pi-subagents/skills/pi-subagents";
    playwright-cli = ".pi/agent/npm/node_modules/@playwright/cli/skills/playwright-cli";
    ponytail-bundle = ".pi/agent/npm/node_modules/@dietrichgebert/ponytail/skills";
  };
in
delib.module {
  name = "codex-skills";

  options = delib.singleEnableOption isMacbook;

  home.ifEnabled = lib.mkIf isMacbook {
    imports = [
      (
        { config, ... }:
        let
          link = config.lib.file.mkOutOfStoreSymlink;
          homeDirectory = config.home.homeDirectory;
          packageSkills = lib.mapAttrs' (
            name: target:
            lib.nameValuePair ".agents/skills/${name}" {
              source = link "${homeDirectory}/${target}";
              force = true;
            }
          ) packageSkillTargets;
        in
        {
          home.file = repositorySkills // packageSkills;
        }
      )
    ];
  };
}
