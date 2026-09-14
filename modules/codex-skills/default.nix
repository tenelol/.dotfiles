{
  delib,
  hm,
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
  extensionSkillTargets = {
    council-mode = ".pi/agent/extensions/pi-subagents/skills/council-mode";
    pi-subagents = ".pi/agent/extensions/pi-subagents/skills/pi-subagents";
    playwright-cli = ".pi/agent/extensions/playwright-cli/node_modules/@playwright/cli/skills/playwright-cli";
    ponytail-bundle = ".pi/agent/extensions/ponytail/skills";
  };
  linkExtensionSkills = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: target:
      ''
        $DRY_RUN_CMD ln -sfn "$HOME/${target}" "$HOME/.agents/skills/${name}"
      ''
    ) extensionSkillTargets
  );
in
delib.module {
  name = "codex-skills";

  options = delib.singleEnableOption isMacbook;

  home.ifEnabled = lib.mkIf isMacbook {
    home.file = repositorySkills;

    home.activation.linkPiExtensionSkills = hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.agents/skills"
      ${linkExtensionSkills}
    '';
  };
}
