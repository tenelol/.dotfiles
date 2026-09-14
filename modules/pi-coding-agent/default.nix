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
    home.file = {
      ".pi/agent/AGENTS.md" = {
        source = ./files/AGENTS.md;
        force = true;
      };
      ".pi/agent/references/delegation.md" = {
        source = ./files/references/delegation.md;
        force = true;
      };
      ".pi/agent/project-context-protocol.md" = {
        source = ../vault-context/files/codex/project-context-protocol.md;
        force = true;
      };
    };
  };
}
