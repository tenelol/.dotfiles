{
  lib,
  runCommand,
}:
{
  name,
  sourcePackage,
  cli ? { },
  wrapCli ? false,
  extraFiles ? { },
  ...
}:
# Runtime commands follow the updated app. Documentation/completions stay in
# the store so Fish can read them while building inside the Nix sandbox.
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
        ln -s ${lib.escapeShellArg "${sourcePackage}/Applications/${source}"} "$out"/${lib.escapeShellArg target}
      '') extraFiles
    )
  )
