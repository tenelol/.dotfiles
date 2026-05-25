{ pkgs, lib }:
let
  pname = "moocs-collect-cli";
  version = "1.0.1";

  srcs = {
    aarch64-darwin = {
      url = "https://github.com/yu7400ki/moocs-collect/releases/download/cli-v${version}/collect-cli-macos-arm64";
      hash = "sha256-fU1a0sOOrI5ARTEEXjgDlIGuSmW217xHdeWnVFR3LPM=";
    };
    x86_64-darwin = {
      url = "https://github.com/yu7400ki/moocs-collect/releases/download/cli-v${version}/collect-cli-macos-amd64";
      hash = "sha256-RB3Xtc6qXK6gIM5W5bvqek4/snnGyQj9QGJoe9Anj+M=";
    };
    x86_64-linux = {
      url = "https://github.com/yu7400ki/moocs-collect/releases/download/cli-v${version}/collect-cli-linux-amd64";
      hash = "sha256-WYFdlIplwbKZ6muJUZb84VX4jKrysFh3eHKl/I0Ffnc=";
    };
  };

  srcInfo =
    srcs.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for ${pname}: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version;

  src = pkgs.fetchurl srcInfo;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/collect-cli"

    runHook postInstall
  '';

  meta = {
    description = "CLI for downloading INIAD MOOCs slides";
    homepage = "https://github.com/yu7400ki/moocs-collect";
    license = lib.licenses.mit;
    mainProgram = "collect-cli";
    platforms = builtins.attrNames srcs;
  };
}
