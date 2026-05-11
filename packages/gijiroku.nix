{
  pkgs,
  lib,
  src,
}:

pkgs.buildNpmPackage {
  pname = "gijiroku";
  version = "0.1.0";

  inherit src;

  npmDepsHash = "sha256-l6s7pMGxtP7rFlLF2/ukV+4cs3Co9nc/chTgayC1np0=";

  cargoRoot = "src-tauri";
  cargoDeps = pkgs.rustPlatform.importCargoLock {
    lockFile = "${src}/src-tauri/Cargo.lock";
  };

  nativeBuildInputs = [
    pkgs.cargo
    pkgs.rustc
    pkgs.rustPlatform.cargoSetupHook
    pkgs.cargo-tauri
  ];

  buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    pkgs.apple-sdk_15
  ];

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"
    cargo tauri build --bundles app

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -R "src-tauri/target/release/bundle/macos/Gijiroku.app" "$out/Applications/"

    printf '%s\n' \
      '#!/bin/sh' \
      "exec /usr/bin/open \"$out/Applications/Gijiroku.app\" \"\$@\"" \
      > "$out/bin/gijiroku"
    chmod +x "$out/bin/gijiroku"

    runHook postInstall
  '';

  meta = {
    description = "Personal macOS call recording and local minutes app";
    homepage = "https://github.com/tenelol/gijiroku";
    license = lib.licenses.unfree;
    mainProgram = "gijiroku";
    platforms = [ "aarch64-darwin" ];
  };
}
