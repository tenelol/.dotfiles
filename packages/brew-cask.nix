{
  lib,
  runCommand,
}:
{
  cask,
  cli ? { },
  wrapCli ? false,
  extraFiles ? { },
  completions ? { },
}:
let
  packaged = cask.overrideAttrs (old: {
    # Link the same app-internal CLI that Homebrew exposed, without changing
    # signed bundle contents or invoking any installer/uninstall hooks.
    # brew-nix's custom installPhase does not run postInstall hooks.
    installPhase =
      old.installPhase
      + lib.concatStrings (
        lib.mapAttrsToList (name: source: ''
        test -x "$out/Applications"/${lib.escapeShellArg source}
        mkdir -p "$out/bin"
        ${if wrapCli then ''
          makeWrapper "$out/Applications"/${lib.escapeShellArg source} "$out/bin"/${lib.escapeShellArg name}
        '' else ''
          ln -sfn "$out/Applications"/${lib.escapeShellArg source} "$out/bin"/${lib.escapeShellArg name}
        ''}
        '') cli
      )
      + lib.concatStrings (
        lib.mapAttrsToList (target: source: ''
          test -f "$out/Applications"/${lib.escapeShellArg source}
          mkdir -p "$out"/${lib.escapeShellArg (builtins.dirOf target)}
          ln -s "$out/Applications"/${lib.escapeShellArg source} "$out"/${lib.escapeShellArg target}
        '') extraFiles
      );
  });
in
packaged
// lib.optionalAttrs (completions != { }) {
  # Generate from the completed bundle, before any invocation can interfere
  # with macOS permissions on an app that is still undergoing fixup.
  completionPackage = runCommand "${packaged.pname}-completions-${packaged.version}" { } (
    lib.concatStrings (
      lib.mapAttrsToList (
        command: shells:
        lib.concatStrings (
          lib.mapAttrsToList (shell: target: ''
            mkdir -p "$out"/${lib.escapeShellArg (builtins.dirOf target)}
            ${lib.escapeShellArg "${packaged}/bin/${command}"} --completions ${lib.escapeShellArg shell} > "$out"/${lib.escapeShellArg target}
          '') shells
        )
      ) completions
    )
  );
}
