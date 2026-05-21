{
  pkgs,
  lib,
}:
let
  pnpm = pkgs.pnpm_8.override { nodejs = pkgs.nodejs; };
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "mygdrive";
  version = "0.1.0";

  src = pkgs.fetchFromGitHub {
    owner = "yossuli";
    repo = "mygdrive";
    rev = "a462ebd63adda8df212b70eddd9a7c26101f1b5d";
    hash = "sha256-z9+8jYZIxPJJgc5fArVukVhni3fXeCztmmT17wkCyKQ=";
  };

  pnpmDeps = pkgs.fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      ;
    inherit pnpm;
    fetcherVersion = 1;
    hash = "sha256-Oiwbd0QfxiJqnoIuAtb1k/Nh02vQtl5tkT/wCSN7CcY=";
  };

  nativeBuildInputs = [
    pkgs.nodejs
    pkgs.pnpmConfigHook
    pnpm
    pkgs.makeBinaryWrapper
  ];

  buildInputs = [
    pkgs.nodejs
  ];

  buildPhase = ''
    runHook preBuild

    pnpm run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/node_modules/mygdrive
    cp -r dist package.json node_modules $out/lib/node_modules/mygdrive/

    makeWrapper ${lib.getExe pkgs.nodejs} $out/bin/mygdrive \
      --add-flags "$out/lib/node_modules/mygdrive/dist/cli.js" \
      --prefix PATH : ${lib.makeBinPath [ pkgs.gdrive ]}

    runHook postInstall
  '';

  meta = {
    description = "TUI wrapper around gdrive for browsing and downloading files";
    homepage = "https://github.com/yossuli/mygdrive";
    license = lib.licenses.mit;
    mainProgram = "mygdrive";
    platforms = lib.platforms.all;
  };
})
