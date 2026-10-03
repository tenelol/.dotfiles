{
  lib,
  runCommand,
  fetchurl,
  callPackage,
}:
let
  version = "2.7.3";
  extracted = (callPackage ./macos-installer-source.nix { }) {
    name = "boringnotch-${version}";
    src = fetchurl {
      url = "https://github.com/TheBoredTeam/boring.notch/releases/download/v${version}/boringNotch.dmg";
      hash = "sha256-I3hjglSNM8WbMJ21WOUTqS4/lbY9YRVE3N310ZbkZpg=";
    };
    artifacts = [ "boringNotch.app" ];
  };
in
runCommand "boringnotch-${version}"
  {
    inherit version;
    meta = {
      description = "Notch utility for macOS";
      homepage = "https://github.com/TheBoredTeam/boring.notch";
      platforms = lib.platforms.darwin;
    };
  }
  ''
    mkdir -p "$out/Applications"
    cp -R ${extracted}/boringNotch.app "$out/Applications/"
  ''
