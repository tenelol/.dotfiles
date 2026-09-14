{
  delib,
  hm,
  host,
  lib,
  pkgs,
  ...
}:
let
  isMacbook = host.name == "macbook" && builtins.match ".*-darwin" host.system != null;
  mergePiConfig = pkgs.writeShellApplication {
    name = "merge-pi-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = builtins.readFile ./files/merge-json-config.sh;
  };
  linkPiSource = pkgs.writeShellApplication {
    name = "link-pi-source";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./files/link-source.sh;
  };
in
delib.module {
  name = "pi-coding-agent";

  options = delib.singleEnableOption isMacbook;

  home.ifEnabled = lib.mkIf isMacbook {
    home.activation.mergePiConfiguration = hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${mergePiConfig}/bin/merge-pi-config \
        "$HOME/.pi/agent/settings.json" \
        ${./files/settings.json}
    '';

    home.activation.linkPiSources = hm.dag.entryAfter [ "linkGeneration" ] ''
      pi_files="$HOME/.dotfiles/modules/pi-coding-agent/files"

      $DRY_RUN_CMD ${linkPiSource}/bin/link-pi-source \
        "$pi_files/art/dashboard-character.txt" \
        "$HOME/.pi/agent/art/dashboard-character.txt"
      $DRY_RUN_CMD ${linkPiSource}/bin/link-pi-source \
        "$pi_files/models.json" \
        "$HOME/.pi/agent/models.json"
      $DRY_RUN_CMD ${linkPiSource}/bin/link-pi-source \
        "$pi_files/themes/tokyonight-muted.json" \
        "$HOME/.pi/agent/themes/tokyonight-muted.json"

      for source in "$pi_files/extensions"/*; do
        $DRY_RUN_CMD ${linkPiSource}/bin/link-pi-source \
          "$source" \
          "$HOME/.pi/agent/extensions/$(basename "$source")"
      done

      for source in "$pi_files/disabled-extensions"/*; do
        $DRY_RUN_CMD ${linkPiSource}/bin/link-pi-source \
          "$source" \
          "$HOME/.pi/agent/disabled-extensions/$(basename "$source")"
      done

      for source in "$pi_files/extensions/pi-subagents/prompts"/*.md; do
        $DRY_RUN_CMD ${linkPiSource}/bin/link-pi-source \
          "$source" \
          "$HOME/.pi/agent/prompts/$(basename "$source")"
      done
    '';

    home.file = {
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
  };
}
