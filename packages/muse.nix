{
  lib,
  runCommand,
  requireFile,
  callPackage,
}:
let
  version = "11.1";
  # muse.ai answers non-browser downloads with 403 not_eligible, so Nix cannot
  # fetch the DMG. Download it from https://muse.ai/ in a browser and register
  # it with `nix store add-file Muse-<version>.dmg` before building.
  src = requireFile {
    name = "Muse-${version}.dmg";
    url = "https://muse.ai/";
    hash = "sha256-+OSazBsQsiHSd1fPG6SjsOL2NjCCpNC+Z+VcWX+OzCs=";
  };
  extracted = (callPackage ./macos-installer-source.nix { }) {
    name = "muse-${version}";
    inherit src;
    artifacts = [ "Muse.app" ];
  };
in
runCommand "muse-${version}"
  {
    inherit version;
    meta = {
      description = "AI assistant for managing tasks, projects, and long-term goals";
      homepage = "https://muse.ai/";
      platforms = lib.platforms.darwin;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
  ''
    mkdir -p "$out/Applications" "$out/nix-support"
    cp -R ${extracted}/Muse.app "$out/Applications/"
    # Keep the hand-downloaded DMG alive across garbage collection; a rebuild
    # after a nixpkgs bump could not fetch it again.
    echo ${src} > "$out/nix-support/source"
  ''
