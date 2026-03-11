{ pkgs, lib }:
let
  version = "0.18.0-beta.3";
  pname = "codexbar";

  srcs = {
    x86_64-linux = {
      url = "https://github.com/steipete/CodexBar/releases/download/v${version}/CodexBarCLI-v${version}-linux-x86_64.tar.gz";
      hash = "sha256-rddc+fhfl10Fnx9ieHedu7ADp6ZxwUs0W05aj4fcPkA=";
    };
    aarch64-linux = {
      url = "https://github.com/steipete/CodexBar/releases/download/v${version}/CodexBarCLI-v${version}-linux-aarch64.tar.gz";
      hash = "sha256-CbyG1F5N9SmMhK+WaqNUkldEYBkIx1DiY7pb063zWcE=";
    };
  };

  srcInfo =
    srcs.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for ${pname}: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenv.mkDerivation {
  inherit pname version;

  src = pkgs.fetchurl srcInfo;

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
  ];

  buildInputs = [
    pkgs.curl
    (lib.getLib pkgs.libxml2_13)
    pkgs.sqlite
    pkgs.stdenv.cc.cc.lib
  ];

  appendRunpaths = [
    "${lib.getLib pkgs.libxml2_13}/lib"
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 codexbar $out/bin/codexbar
    install -Dm755 CodexBarCLI $out/bin/CodexBarCLI

    runHook postInstall
  '';

  meta = with lib; {
    description = "Menu bar app companion CLI for monitoring AI coding tools";
    homepage = "https://github.com/steipete/CodexBar";
    license = licenses.mit;
    platforms = builtins.attrNames srcs;
    mainProgram = "codexbar";
  };
}
