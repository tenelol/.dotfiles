{ pkgs, lib }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "notchmusic";
  version = "0.1.0";

  src = ./notchmusic;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -R "$src/NotchMusic.app" "$out/Applications/"

    printf '%s\n' \
      '#!/bin/sh' \
      "exec /usr/bin/open \"$out/Applications/NotchMusic.app\" \"\$@\"" \
      > "$out/bin/notchmusic"
    chmod +x "$out/bin/notchmusic"

    runHook postInstall
  '';

  meta = {
    description = "Dynamic Island-style Apple Music and Spotify player for MacBook notch";
    homepage = "https://github.com/kuraryu405/NotchMusic";
    license = lib.licenses.mit;
    mainProgram = "notchmusic";
    platforms = [ "aarch64-darwin" ];
  };
}
