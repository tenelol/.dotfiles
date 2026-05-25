{
  pkgs,
  lib,
  collectCli ? import ./moocs-collect-cli.nix { inherit pkgs lib; },
}:

pkgs.stdenvNoCC.mkDerivation {
  pname = "imoocs";
  version = "0.1.0";

  src = ../config/scripts/imoocs;
  dontUnpack = true;

  nativeBuildInputs = [
    pkgs.makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/imoocs"
    wrapProgram "$out/bin/imoocs" \
      --prefix PATH : ${
        lib.makeBinPath [
          collectCli
          pkgs.coreutils
          pkgs.findutils
          pkgs.python3
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Agent-safe wrapper for INIAD MOOCs operations backed by moocs-collect";
    homepage = "https://github.com/yu7400ki/moocs-collect";
    license = lib.licenses.mit;
    mainProgram = "imoocs";
    platforms = collectCli.meta.platforms or lib.platforms.unix;
  };
}
