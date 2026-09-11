{
  delib,
  host,
  lib,
  ...
}:
let
  isMacbook = host.name == "macbook" && builtins.match ".*-darwin" host.system != null;
  skillRoot = ../.agents/skills;
  skills = lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillRoot);
  skillFiles = lib.mapAttrs' (
    name: _:
    lib.nameValuePair ".agents/skills/${name}" {
      # Link each skill atomically so existing agent symlinks cannot redirect
      # recursive Home Manager writes back into the repository source.
      source = skillRoot + "/${name}";
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
