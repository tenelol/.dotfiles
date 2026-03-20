{
  pkgs,
  lib,
}:
{
  publisher,
  name,
  version,
  src,
  meta ? { },
}:
let
  vscodeExtUniqueId = "${publisher}.${name}";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "vscode-extension-${publisher}-${name}";
  inherit version src;

  dontUnpack = true;

  installPhase = ''
    mkdir -p "$out/share/vscode/extensions/${vscodeExtUniqueId}"
    cp -R "$src"/. "$out/share/vscode/extensions/${vscodeExtUniqueId}/"
  '';

  passthru = {
    vscodeExtPublisher = publisher;
    vscodeExtName = name;
    inherit vscodeExtUniqueId;
  };

  meta = meta // {
    platforms = meta.platforms or lib.platforms.linux;
  };
}
