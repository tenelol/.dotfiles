{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "rift";
  version = "0.6.0";

  src = fetchurl {
    url = "https://github.com/acsandmann/rift/releases/download/v${finalAttrs.version}/rift-universal-macos-${finalAttrs.version}.tar.gz";
    hash = "sha256-zhLBnH4EFqV8q1ONRBs2d6ZCXrhFhkaI5xAxtEmQY54=";
  };

  dontUnpack = true;
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/rift"
    tar -xzf "$src" -C "$out/bin" rift rift-cli
    tar -xzf "$src" -C "$out/share/rift" rift.default.toml
    chmod 755 "$out/bin/rift" "$out/bin/rift-cli"
    /usr/bin/codesign --force --sign - "$out/bin/rift"
    /usr/bin/codesign --force --sign - "$out/bin/rift-cli"
    runHook postInstall
  '';

  meta = {
    description = "Tiling window manager for macOS";
    homepage = "https://github.com/acsandmann/rift";
    license = lib.licenses.asl20;
    platforms = lib.platforms.darwin;
    mainProgram = "rift";
  };
})
