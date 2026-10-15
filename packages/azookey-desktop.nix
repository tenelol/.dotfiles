{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
let
  bundleId = "dev.ensan.inputmethod.azooKeyMac";
in
stdenvNoCC.mkDerivation {
  pname = "azookey-desktop";
  version = "0.1.5-beta.1-unstable-2026-09-27";

  src = fetchFromGitHub {
    owner = "azooKey";
    repo = "azooKey-Desktop";
    rev = "bd90b7bdc8f38069987b36426b990ef3129edf62";
    # Zenzai の重みと言語モデルは LFS 管理の submodule にある
    fetchSubmodules = true;
    fetchLFS = true;
    hash = "sha256-U3KkU2Ef+xyK07twh8vY7WbJz7h83AiuEzBT7h3APTo=";
  };

  patches = [ ./azookey-desktop/dopamine-effects.patch ];

  # Nix のビルド環境では sandbox-exec を重ねられないため、SwiftPM の manifest・plugin と
  # Swift macro の sandbox を外す（xcodebuild 側は buildPhase の引数で指定する）
  postPatch = ''
    substituteInPlace Tools/embed_converter_server.sh \
      --replace-fail "swift build " "swift build --disable-sandbox "
  '';

  # xcodebuild と SwiftPM がビルド中に Package.resolved の依存を取得するため、
  # sandbox の外でシステムの Xcode を使ってビルドする。
  __noChroot = true;
  dontConfigure = true;
  # 署名済み bundle を fixup で書き換えない
  dontFixup = true;

  buildPhase = ''
    runHook preBuild
    # stdenv の SDK・コンパイラ変数を外し、Xcode の既定ツールチェーンに任せる。
    # Xcode と SwiftPM は HOME ではなくユーザーレコードの /var/empty にキャッシュを
    # 書こうとするため、CFFIXED_USER_HOME でビルドディレクトリへ向ける。
    /usr/bin/env -i \
      HOME="$TMPDIR" CFFIXED_USER_HOME="$TMPDIR" TMPDIR="$TMPDIR" \
      PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      /usr/bin/xcodebuild \
        -project azooKeyMac.xcodeproj \
        -scheme azooKeyMac \
        -configuration Release \
        -derivedDataPath "$TMPDIR/DerivedData" \
        -packageCachePath "$TMPDIR/swiftpm-cache" \
        -skipPackagePluginValidation \
        -skipMacroValidation \
        -IDEPackageSupportDisableManifestSandbox=YES \
        -IDEPackageSupportDisablePluginExecutionSandbox=YES \
        'OTHER_SWIFT_FLAGS=$(inherited) -Xfrontend -disable-sandbox' \
        CODE_SIGNING_ALLOWED=NO \
        build
    runHook postBuild
  '';

  # 開発者証明書は Nix のビルドユーザーから使えないため ad-hoc 署名する。
  # bundle ID と App Group は公式版と同じなので、既存の入力ソースと共有データをそのまま使える。
  installPhase = ''
    runHook preInstall
    app="$out/azooKeyMac.app"
    server="$app/Contents/Helpers/ConverterServer"
    mkdir -p "$out"
    /usr/bin/ditto "$TMPDIR/DerivedData/Build/Products/Release/azooKeyMac.app" "$app"
    sed 's/$(PRODUCT_BUNDLE_IDENTIFIER)/${bundleId}/' azooKeyMac/azooKeyMac.entitlements \
      > "$TMPDIR/azooKeyMac.entitlements"

    for nested in "$app"/Contents/Frameworks/* "$server"/*.bundle; do
      /usr/bin/codesign --force --sign - "$nested"
    done
    /usr/bin/codesign --force --sign - \
      --identifier ${bundleId}.ConverterServer \
      --entitlements azooKeyMac/ConverterServer.entitlements \
      "$server/ConverterServer"
    /usr/bin/codesign --force --sign - \
      --entitlements "$TMPDIR/azooKeyMac.entitlements" \
      "$app"
    /usr/bin/codesign --verify --deep --strict "$app"
    runHook postInstall
  '';

  passthru = {
    inherit bundleId;
    converterServer = "azooKeyMac.app/Contents/Helpers/ConverterServer/ConverterServer";
  };

  meta = {
    description = "azooKey for macOS with combo typing effects";
    homepage = "https://github.com/azooKey/azooKey-Desktop";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
}
