{ pkgs, lib }:
let
  version = "0.3.4";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "palmier-pro";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/palmier-io/palmier-pro/releases/download/v${version}/PalmierPro.dmg";
    hash = "sha256-7GctHjHCIMcvfElH4eVQcEES6tDUYYY+v1mVHp02xH8=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mount_point="$(mktemp -d)"
    /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$mount_point" "$src"
    trap '/usr/bin/hdiutil detach "$mount_point"' EXIT

    mkdir -p "$out/Applications"
    cp -R "$mount_point/PalmierPro.app" "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "macOS video editor built for AI";
    homepage = "https://github.com/palmier-io/palmier-pro";
    license = lib.licenses.gpl3Only;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
