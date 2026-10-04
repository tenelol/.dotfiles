{
  lib,
  runCommand,
}:
{
  name,
  cli ? { },
  wrapCli ? false,
  extraFiles ? { },
  ...
}:
# Only integration files belong in the Nix profile. Runtime commands and man
# pages follow the normal app copy, including changes made by its own updater.
runCommand "${name}-app-support"
  {
    pname = "${name}-app-support";
  }
  (
    "mkdir -p \"$out\"\n"
    + lib.concatStrings (
      lib.mapAttrsToList (command: source: ''
        mkdir -p "$out/bin"
        ${
          if wrapCli then
            ''
              cat > "$out/bin"/${lib.escapeShellArg command} <<'SH'
              #!/bin/sh
              exec ${lib.escapeShellArg "/Applications/${source}"} "$@"
              SH
              chmod +x "$out/bin"/${lib.escapeShellArg command}
            ''
          else
            ''
              ln -s ${lib.escapeShellArg "/Applications/${source}"} "$out/bin"/${lib.escapeShellArg command}
            ''
        }
      '') cli
    )
    + lib.concatStrings (
      lib.mapAttrsToList (target: source: ''
        mkdir -p "$out"/${lib.escapeShellArg (builtins.dirOf target)}
        ln -s ${lib.escapeShellArg "/Applications/${source}"} "$out"/${lib.escapeShellArg target}
      '') extraFiles
    )
  )
