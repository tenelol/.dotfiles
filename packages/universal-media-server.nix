{
  fetchurl,
  ffmpeg,
  jre17_minimal,
  lib,
  makeWrapper,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "universal-media-server";
  version = "13.8.0";

  src = fetchurl {
    url = "https://github.com/UniversalMediaServer/UniversalMediaServer/releases/download/${finalAttrs.version}/UMS-${finalAttrs.version}-x86_64.tgz";
    hash = "sha256-IU3aQfHF1B3zzBG0+aKfatvmHk6eZD6OG5LcyjB+7rA=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/ums" "$out/bin"
    cp -R . "$out/share/ums"
    rm -rf "$out/share/ums/jre17"
    makeWrapper "$out/share/ums/UMS.sh" "$out/bin/ums" \
      --set JAVA_HOME ${jre17_minimal} \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg ]}
    runHook postInstall
  '';

  meta = {
    description = "DLNA-compliant UPnP media server";
    homepage = "https://www.universalmediaserver.com/";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ums";
  };
})
