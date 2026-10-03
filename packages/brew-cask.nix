{
  lib,
  runCommand,
  python3,
  fetchurl,
}:
{
  cask,
  cli ? { },
  wrapCli ? false,
  extraFiles ? { },
  completions ? { },
  completionArgs ? [ "--completions" ],
  sourceHash ? null,
  sourceUrl ? null,
  fontFiles ? [ ],
  archiveMembers ? [ ],
}:
let
  packaged = cask.overrideAttrs (old: {
    src =
      if sourceUrl != null then
        fetchurl {
          url = sourceUrl;
          hash = sourceHash;
        }
      else if sourceHash == null then
        old.src
      else
        old.src.overrideAttrs (_: {
          outputHash = sourceHash;
          outputHashAlgo = "sha256";
        });
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ lib.optional (fontFiles != [ ]) python3;
    sourceRoot = if fontFiles == [ ] then old.sourceRoot else "font-source";
    unpackPhase =
      if fontFiles == [ ] then
        old.unpackPhase
      else
        ''
          mkdir font-source
          case "$src" in
            *.zip) unzip -q "$src" -d font-source ;;
            *.tar.*|*.tgz) tar -xf "$src" -C font-source ${lib.escapeShellArgs archiveMembers} ;;
            *) cp "$src" font-source/${lib.escapeShellArg (builtins.head fontFiles)} ;;
          esac
        '';
    # Link the same app-internal CLI that Homebrew exposed, without changing
    # signed bundle contents or invoking any installer/uninstall hooks.
    # brew-nix's custom installPhase does not run postInstall hooks.
    installPhase =
      (
        if fontFiles == [ ] then
          old.installPhase
        else
          ''
            python3 - ${lib.escapeShellArg (builtins.toJSON fontFiles)} "$out" <<'PY'
            import json, pathlib, shutil, sys
            root = pathlib.Path.cwd()
            output = pathlib.Path(sys.argv[2]) / "share/fonts"
            output.mkdir(parents=True)
            roots = [root] + [p for p in root.iterdir() if p.is_dir()]
            for relative in json.loads(sys.argv[1]):
                matches = [base / relative for base in roots if (base / relative).is_file()]
                if len(matches) != 1:
                    raise SystemExit(f"Expected one font {relative!r}, got {len(matches)}")
                target = output / matches[0].name
                shutil.copyfile(matches[0], target)
                target.chmod(0o644)
            PY
          ''
      )
      + lib.concatStrings (
        lib.mapAttrsToList (name: source: ''
          test -x "$out/Applications"/${lib.escapeShellArg source}
          mkdir -p "$out/bin"
          ${
            if wrapCli then
              ''
                makeWrapper "$out/Applications"/${lib.escapeShellArg source} "$out/bin"/${lib.escapeShellArg name}
              ''
            else
              ''
                ln -sfn "$out/Applications"/${lib.escapeShellArg source} "$out/bin"/${lib.escapeShellArg name}
              ''
          }
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
            ${lib.escapeShellArg "${packaged}/bin/${command}"} ${lib.escapeShellArgs completionArgs} ${lib.escapeShellArg shell} > "$out"/${lib.escapeShellArg target}
          '') shells
        )
      ) completions
    )
  );
}
