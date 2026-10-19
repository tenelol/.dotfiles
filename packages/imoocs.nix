{
  pkgs,
  lib,
}:
let
  pythonWithKeyring = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.browser-cookie3
    pythonPackages.keyring
  ]);
in

pkgs.stdenvNoCC.mkDerivation {
  pname = "imoocs";
  version = "0.3.11";

  src = ./imoocs/imoocs;
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
          pkgs.coreutils
          pkgs.findutils
          pythonWithKeyring
          pkgs.qpdf
          pkgs.resvg
          pkgs.svg2pdf
          (pkgs.tesseract.override {
            enableLanguages = [
              "eng"
              "jpn"
            ];
          })
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Agent-safe wrapper for INIAD MOOCs operations";
    homepage = "https://moocs.iniad.org";
    license = lib.licenses.mit;
    mainProgram = "imoocs";
    platforms = lib.platforms.unix;
  };
}
