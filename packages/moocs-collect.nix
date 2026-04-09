{ pkgs, lib }:
let
  pname = "moocs-collect";
  version = "1.0.1";

  srcs = {
    aarch64-darwin = {
      url = "https://github.com/yu7400ki/moocs-collect/releases/download/app-v${version}/collect_${version}_aarch64.dmg";
      hash = "sha256-erlv0ReD6SVdvKMklHIyLswmwMzjME45pyXuS89IqFY=";
    };
    x86_64-darwin = {
      url = "https://github.com/yu7400ki/moocs-collect/releases/download/app-v${version}/collect_${version}_x64.dmg";
      hash = "sha256-zBKO0AWrGU+XQvFS57K/jHkX3C9nRIo8uIW0l4eIAdA=";
    };
  };

  srcInfo =
    srcs.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for ${pname}: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version;

  src = pkgs.fetchurl srcInfo;
  nativeBuildInputs = [
    pkgs.undmg
  ];

  sourceRoot = ".";

  unpackPhase = ''
    runHook preUnpack
    undmg "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -R "collect.app" "$out/Applications/"
    ln -s "$out/Applications/collect.app/Contents/MacOS/app" "$out/bin/collect"

    runHook postInstall
  '';

  meta = {
    description = "Desktop app for searching MOOCs";
    homepage = "https://github.com/yu7400ki/moocs-collect";
    license = lib.licenses.mit;
    mainProgram = "collect";
    platforms = builtins.attrNames srcs;
  };
}
