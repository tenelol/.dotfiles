{ pkgs, lib }:
let
  root = ./pi-extensions;
  sources = builtins.fromJSON (builtins.readFile (root + /sources.json));
  mkExtension = name: source:
    let
      common = {
        pname = name;
        inherit (source) version;
        src = pkgs.fetchurl {
          inherit (source) url hash;
        };
        patches = map (patch: root + "/patches/${patch}") source.patches;
        patchFlags = [ "-p1" "--fuzz=0" ];
        dontBuild = true;
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          cp -R . "$out/"
          runHook postInstall
        '';
        meta = {
          description = "Pinned upstream Pi extension with local patches";
          homepage = lib.removePrefix "git+" source.repository.url;
          platforms = lib.platforms.unix;
        };
      };
    in
    if source ? lock then
      pkgs.buildNpmPackage (common // {
        inherit (source) npmDepsHash;
        postPatch = ''
          cp ${root + "/locks/${source.lock}"} package-lock.json
          ${lib.getExe pkgs.jq} 'del(.devDependencies)' package.json > package.json.tmp
          mv package.json.tmp package.json
        '';
        npmFlags = [ "--legacy-peer-deps" ];
        npmInstallFlags = [ "--omit=dev" "--omit=peer" ];
        # Published runtimes are already built. Match the existing script-free installs.
        npmRebuildFlags = [ "--ignore-scripts" ];
        dontNpmBuild = true;
      })
    else
      pkgs.stdenvNoCC.mkDerivation common;
in
lib.mapAttrs mkExtension sources
