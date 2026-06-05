{ pkgs, lib }:
let
  pname = "azoo-key-skkserv";
  version = "0.4.0";

  srcs = {
    aarch64-darwin = {
      url = "https://github.com/gitusp/azoo-key-skkserv/releases/download/v${version}/arm64-apple-macosx-${version}.zip";
      hash = "sha256-dt1Iztym9PynnPbBbmR7PkP8CE9mjizGIs7PMaTp4go=";
      sourceRoot = "arm64-apple-macosx/release";
    };
  };

  srcInfo =
    srcs.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for ${pname}: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version;

  src = pkgs.fetchurl {
    inherit (srcInfo) url hash;
  };
  inherit (srcInfo) sourceRoot;

  nativeBuildInputs = [
    pkgs.unzip
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -d "$out/libexec/${pname}" "$out/bin"
    cp -R . "$out/libexec/${pname}/"
    chmod +x "$out/libexec/${pname}/${pname}"

    printf '%s\n' '#!${pkgs.runtimeShell}' \
      "exec \"$out/libexec/${pname}/${pname}\" \"\$@\"" \
      > "$out/bin/${pname}"
    chmod +x "$out/bin/${pname}"

    runHook postInstall
  '';

  meta = {
    description = "azooKey Kana-Kanji conversion engine exposed as an SKK server";
    homepage = "https://github.com/gitusp/azoo-key-skkserv";
    license = lib.licenses.asl20;
    mainProgram = pname;
    platforms = builtins.attrNames srcs;
  };
}
