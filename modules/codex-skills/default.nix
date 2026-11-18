{
  delib,
  hostTraits,
  hm,
  lib,
  ...
}:
let
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
  # Keep parent-side Claude delegation, Codex model routing, and Pi runtime skills out of Claude Code.
  runtimeSpecificSkills = [
    "ask-claude"
    "council-mode"
    "pi-subagents"
    "subagent-model-router"
  ];
  claudeSkillTargets =
    lib.mapAttrs (name: _: ".agents/skills/${name}") (
      builtins.removeAttrs (skills // extensionSkillTargets) (
        runtimeSpecificSkills ++ [ "ponytail-bundle" ]
      )
    )
    // lib.genAttrs [
      "ponytail"
      "ponytail-audit"
      "ponytail-debt"
      "ponytail-gain"
      "ponytail-help"
      "ponytail-review"
    ] (name: ".agents/skills/ponytail-bundle/${name}");
  # App-bundled skills ship and update with their app, so link each agent's
  # skill directory into the installed bundle instead of copying the files.
  # Phi's skill drives Phi over CDP and must match the installed Phi version.
  appBundledSkills = {
    phi-browser = {
      source = "/Applications/Phi.app/Contents/Resources/phi-browser-skill";
      targets = [
        ".claude/skills"
        ".codex/skills"
        ".gemini/config/skills"
        ".pi/agent/skills"
      ];
    };
  };
  linkExtensionSkills = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: target: ''
      $DRY_RUN_CMD ln -sfn "$HOME/${target}" "$HOME/.agents/skills/${name}"
    '') extensionSkillTargets
  );
in
delib.module {
  name = "codex-skills";

  options = delib.singleEnableOption hostTraits.macbook;

  home.ifEnabled = {
    home.file = repositorySkills;

    imports = [
      (
        { config, ... }:
        {
          # Antigravity and its CLI read global skills from ~/.gemini/config/skills.
          home.file =
            lib.concatMapAttrs (
              name: target:
              lib.genAttrs' [ ".claude/skills" ".gemini/config/skills" ] (
                dir:
                lib.nameValuePair "${dir}/${name}" {
                  source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${target}";
                  force = true;
                }
              )
            ) claudeSkillTargets
            // lib.concatMapAttrs (
              name: skill:
              lib.listToAttrs (
                map (
                  dir:
                  lib.nameValuePair "${dir}/${name}" {
                    source = config.lib.file.mkOutOfStoreSymlink skill.source;
                    force = true;
                  }
                ) skill.targets
              )
            ) appBundledSkills;
        }
      )
    ];

    home.activation.linkPiExtensionSkills = hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.agents/skills"
      ${linkExtensionSkills}
    '';
  };
}
