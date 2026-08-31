{
  delib,
  host,
  lib,
  ...
}:
let
  isMacbook = host.name == "macbook" && builtins.match ".*-darwin" host.system != null;
  skillRoot = ../.codex/skills;
  skills = lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillRoot);
  skillFiles = lib.mapAttrs' (
    name: _:
    lib.nameValuePair ".codex/skills/${name}" {
      source = skillRoot + "/${name}";
      recursive = true;
      force = true;
    }
  ) skills;
in
delib.module {
  name = "codex-skills";

  options = delib.singleEnableOption isMacbook;

  home.ifEnabled = lib.mkIf isMacbook {
    home.file = skillFiles;
  };
}
