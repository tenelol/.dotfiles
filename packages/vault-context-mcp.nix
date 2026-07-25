{
  buildNpmPackage,
  lib,
  sqlite,
}:
buildNpmPackage {
  pname = "vault-context-mcp";
  version = "0.3.0";

  src = ../config/codex/vault-context-mcp;
  npmDepsHash = "sha256-PlESTDWZBBqqRSP+vN5rudbUNrFPKLZ6Noi1j/yPucI=";

  dontNpmBuild = true;
  doCheck = true;
  nativeCheckInputs = [ sqlite ];
  checkPhase = ''
    runHook preCheck
    npm test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/vault-context-mcp"
    cp -R package.json package-lock.json schema scripts src test node_modules \
      "$out/share/vault-context-mcp/"
    runHook postInstall
  '';

  meta = {
    description = "Local AI-first Obsidian Vault context MCP runtime";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
}
