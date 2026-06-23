{
  pkgs,
  lib,
  hermesDesktop,
}:

pkgs.stdenvNoCC.mkDerivation {
  pname = "hermes-agent-desktop-app";
  version = hermesDesktop.version or "0.17.0";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    app="$out/Applications/Hermes Agent.app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$out/bin"

    cat > "$app/Contents/Info.plist" <<'EOF'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
      "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleDevelopmentRegion</key>
      <string>en</string>
      <key>CFBundleDisplayName</key>
      <string>Hermes Agent</string>
      <key>CFBundleExecutable</key>
      <string>Hermes Agent</string>
      <key>CFBundleIdentifier</key>
      <string>com.nousresearch.hermes-agent-desktop</string>
      <key>CFBundleName</key>
      <string>Hermes Agent</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleShortVersionString</key>
      <string>${hermesDesktop.version or "0.17.0"}</string>
      <key>CFBundleVersion</key>
      <string>${hermesDesktop.version or "0.17.0"}</string>
      <key>LSApplicationCategoryType</key>
      <string>public.app-category.productivity</string>
    </dict>
    </plist>
    EOF

    cat > "$app/Contents/MacOS/Hermes Agent" <<'EOF'
    #!${pkgs.runtimeShell}
    exec ${lib.getExe hermesDesktop} "$@"
    EOF
    chmod +x "$app/Contents/MacOS/Hermes Agent"

    ln -s ${lib.getExe hermesDesktop} "$out/bin/hermes-desktop"
    cat > "$out/bin/hermes-agent-desktop" <<EOF
    #!${pkgs.runtimeShell}
    exec /usr/bin/open -na "$app" --args "\$@"
    EOF
    chmod +x "$out/bin/hermes-agent-desktop"

    runHook postInstall
  '';

  meta = {
    description = "macOS app wrapper for Hermes Agent Desktop";
    homepage = "https://github.com/NousResearch/hermes-agent";
    license = lib.licenses.asl20;
    mainProgram = "hermes-agent-desktop";
    platforms = [ "aarch64-darwin" ];
  };
}
