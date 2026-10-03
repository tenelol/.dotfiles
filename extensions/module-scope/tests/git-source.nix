let
  repository = toString ../../../.;
  source = (builtins.getFlake "git+file://${repository}").outPath;
  required = [
    "extensions/module-scope/default.nix"
    "modules/host-policy/default.nix"
    "modules/desktop/default.nix"
    "modules/brew-casks/default.nix"
    "modules/brew-casks/files/apps.json"
    "packages/brew-cask.nix"
  ];
in
map (
  path:
  if builtins.pathExists (source + "/${path}") then
    path
  else
    throw "${path} is missing from the Git flake source; add it to Git before evaluating configurations"
) required
