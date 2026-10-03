{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "rift";
  # Preserve the working Homebrew release while migrating its runtime to Nix.
  version = "0.5.8.1";

  src = fetchurl {
    url = "https://github.com/acsandmann/rift/releases/download/v${finalAttrs.version}/rift-universal-macos-${finalAttrs.version}.tar.gz";
    hash = "sha256-cBzVzP4KaQQ5AnAkdmkbAPszAUBiOAW7h1BiYriLubY=";
  };

  dontUnpack = true;
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    tar -xzf "$src" -C "$out/bin" rift rift-cli
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
