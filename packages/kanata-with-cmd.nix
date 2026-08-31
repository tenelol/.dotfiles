{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
}:
stdenvNoCC.mkDerivation {
  pname = "kanata-with-cmd";
  version = "1.12.0";

  src = fetchurl {
    url = "https://github.com/jtroo/kanata/releases/download/v1.12.0/macos-binaries-arm64.zip";
    hash = "sha256-g5dp0YmRG1iB4RVQ6qIDlwUhP7clhl0Ij1ouOmwQ3jI=";
  };

  unpackPhase = ''
    runHook preUnpack
    ${unzip}/bin/unzip "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 kanata_macos_cmd_allowed_arm64 "$out/bin/kanata"
    runHook postInstall
  '';

  meta = {
    description = "Official macOS Kanata binary with command actions enabled";
    homepage = "https://github.com/jtroo/kanata";
    license = lib.licenses.lgpl3Only;
    mainProgram = "kanata";
    platforms = [ "aarch64-darwin" ];
  };
}
