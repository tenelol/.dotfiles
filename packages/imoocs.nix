{
  pkgs,
  lib,
  collectCli ? import ./moocs-collect-cli.nix { inherit pkgs lib; },
}:
let
  pythonWithKeyring = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.keyring
  ]);
in

pkgs.stdenvNoCC.mkDerivation {
  pname = "imoocs";
  version = "0.2.8";

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
          pkgs.expect
          pkgs.findutils
          pythonWithKeyring
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Agent-safe wrapper for INIAD MOOCs operations";
    homepage = "https://github.com/yu7400ki/moocs-collect";
    license = lib.licenses.mit;
    mainProgram = "imoocs";
    platforms = collectCli.meta.platforms or lib.platforms.unix;
  };
}
