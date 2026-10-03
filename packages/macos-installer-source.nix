{
  lib,
  runCommand,
  undmg,
  _7zz,
}:
{
  name,
  src,
  artifacts,
  sourcePaths ? { },
}:
runCommand "${name}-installer-source"
  {
    inherit src;
    nativeBuildInputs = [
      undmg
      _7zz
    ];
  }
  ''
    mkdir seven undmg "$out"
    cd seven
    complete=1
    if ! 7zz x -y -snld20 "$src" >/dev/null; then
      complete=0
    fi
    # 7zz materializes HFS extended attributes as sidecar files. They are not
    # part of the signed bundle and make codesign reject frameworks.
    find . -type f -name '*:com.apple.*' -delete
    ${lib.concatMapStringsSep "\n" (
      artifact:
      if builtins.hasAttr artifact sourcePaths then
        ''
          if [ ! -e ${lib.escapeShellArg sourcePaths.${artifact}} ]; then complete=0; fi
        ''
      else
        ''
          count=$(find . -name ${lib.escapeShellArg artifact} -print | wc -l | tr -d ' ')
          if [ "$count" != 1 ]; then complete=0; fi
        ''
    ) artifacts}
    if [ "$complete" != 1 ]; then
      cd ../undmg
      undmg "$src" >/dev/null
    fi

    ${lib.concatMapStringsSep "\n" (
      artifact:
      if builtins.hasAttr artifact sourcePaths then
        ''
          test -e ${lib.escapeShellArg sourcePaths.${artifact}}
          cp -R ${lib.escapeShellArg sourcePaths.${artifact}} "$out"/${lib.escapeShellArg artifact}
        ''
      else
        ''
          matches=$(find . -name ${lib.escapeShellArg artifact} -print)
          if [ "$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')" != 1 ]; then
            echo "expected exactly one ${artifact} in ${name} source" >&2
            exit 1
          fi
          cp -R "$matches" "$out"/${lib.escapeShellArg artifact}
        ''
    ) artifacts}
  ''
