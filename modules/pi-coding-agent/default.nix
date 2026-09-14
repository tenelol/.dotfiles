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
in
delib.module {
  name = "pi-coding-agent";

  options = delib.singleEnableOption isMacbook;

  home.ifEnabled = lib.mkIf isMacbook {
    home.activation.mergePiConfiguration = hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${mergePiConfig}/bin/merge-pi-config \
        "$HOME/.pi/agent/settings.json" \
        ${./files/settings.json}
      $DRY_RUN_CMD ${mergePiConfig}/bin/merge-pi-config \
        "$HOME/.pi/agent/extensions/pi-tool-display/config.json" \
        ${./files/extensions/pi-tool-display/config.json}
    '';

    home.file = {
      ".pi/agent/AGENTS.md" = {
        source = ./files/AGENTS.md;
        force = true;
      };
      ".pi/agent/art/dashboard-character.txt" = {
        source = ./files/art/dashboard-character.txt;
        force = true;
      };
      ".pi/agent/extensions/dashboard-header.ts" = {
        source = ./files/extensions/dashboard-header.ts;
        force = true;
      };
      ".pi/agent/extensions/playwright-cli.ts" = {
        source = ./files/extensions/playwright-cli.ts;
        force = true;
      };
      ".pi/agent/models.json" = {
        source = ./files/models.json;
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
      ".pi/agent/themes/tokyonight-muted.json" = {
        source = ./files/themes/tokyonight-muted.json;
        force = true;
      };
    };
  };
}
