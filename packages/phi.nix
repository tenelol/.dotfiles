{
  lib,
  runCommand,
  fetchurl,
  callPackage,
}:
let
  # Phi ships through the vendor tap (phibrowser/tap), which brew-nix does not pin.
  version = "2.16.1";
  build = "965";
  extracted = (callPackage ./macos-installer-source.nix { }) {
    name = "phi-${version}";
    src = fetchurl {
      url = "https://ota.phibrowser.com/mac-public/releases/Phi_${version}_${build}.zip";
      hash = "sha256-ageU0sIlq1xwSrx+q3uKV3fBbTI0gVkyhLnx6cN+1PI=";
    };
    artifacts = [ "Phi.app" ];
  };
in
runCommand "phi-${version}"
  {
    inherit version;
    meta = {
      description = "Chromium-based web browser with a built-in AI assistant";
      homepage = "https://phibrowser.com/";
      platforms = [ "aarch64-darwin" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
  ''
    mkdir -p "$out/Applications"
    cp -R ${extracted}/Phi.app "$out/Applications/"
  ''
