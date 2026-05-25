{ pkgs, lib }:

pkgs.buildNpmPackage rec {
  pname = "ccpocket-bridge";
  version = "1.61.4";

  src = pkgs.fetchFromGitHub {
    owner = "K9i-0";
    repo = "ccpocket";
    rev = "bridge/v${version}";
    hash = "sha256-utR7wbtp6RuGQTN/lvY2WHHN6T6wTUP8enKThqtcvsg=";
  };

  npmWorkspace = "packages/bridge";
  npmDepsHash = "sha256-efzORJtDoOpkUo/9SXKgFdWOPsJqwrKjB2coSH6iPBw=";

  nativeBuildInputs = [
    pkgs.makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --ignore-scripts --workspace=packages/bridge

    bridge_dir="$out/lib/node_modules/@ccpocket/bridge"
    mkdir -p "$bridge_dir" "$out/bin"
    cp -R \
      packages/bridge/dist \
      packages/bridge/package.json \
      packages/bridge/README.md \
      packages/bridge/LICENSE \
      "$bridge_dir/"
    cp -R node_modules "$bridge_dir/node_modules"
    cp -R packages/bridge/node_modules/* "$bridge_dir/node_modules/"

    rm -f "$bridge_dir/node_modules/@ccpocket/bridge"
    rm -f "$bridge_dir/node_modules/.bin/ccpocket-bridge"

    makeWrapper ${lib.getExe pkgs.nodejs} "$out/bin/ccpocket-bridge" \
      --add-flags "$bridge_dir/dist/cli.js"

    runHook postInstall
  '';

  meta = {
    description = "CC Pocket bridge server for Codex and Claude coding-agent sessions";
    homepage = "https://github.com/K9i-0/ccpocket";
    license = lib.licenses.mit;
    mainProgram = "ccpocket-bridge";
    platforms = lib.platforms.darwin;
  };
}
