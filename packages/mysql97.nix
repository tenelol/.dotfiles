{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "mysql";
  version = "9.7.1";

  # Oracle's signed macOS archive is self-contained and resolves its bundled
  # libraries relative to each executable. Keep it intact for code signing.
  src = fetchurl {
    url = "https://cdn.mysql.com/Downloads/MySQL-9.7/mysql-${finalAttrs.version}-macos15-arm64.tar.gz";
    hash = "sha256-w0RPHz5RXgGgORYhnhiA6zOi4gaWwiiGbg6soa8tuFI=";
  };

  dontUnpack = true;
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    tar -xzf "$src" -C "$out" --strip-components=1
    runHook postInstall
  '';

  meta = {
    description = "MySQL Community Server and client";
    homepage = "https://dev.mysql.com/downloads/mysql/";
    license = lib.licenses.gpl2Only;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "mysql";
  };
})
