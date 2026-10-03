{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "peekaboo";
  version = "4.5.0";

  # The upstream macOS binary retains its Developer ID signature.
  src = fetchurl {
    url = "https://github.com/openclaw/Peekaboo/releases/download/v${finalAttrs.version}/peekaboo-macos-arm64.tar.gz";
    hash = "sha256-plMj5ceaAJTIYBmchvmSSMYJVdmAOsL6emKxhJQYa+s=";
  };

  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    tar -xzf "$src" -C "$out/bin" --strip-components=1 \
      peekaboo-macos-arm64/peekaboo \
      peekaboo-macos-arm64/libswiftCompatibilitySpan.dylib
    chmod 755 "$out/bin/peekaboo"
    runHook postInstall
  '';

  meta = {
    description = "macOS screenshot and computer interaction CLI";
    homepage = "https://github.com/openclaw/Peekaboo";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "peekaboo";
  };
})
