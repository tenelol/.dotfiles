{
  delib,
  homeDir,
  hostTraits,
  hm,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  sharedRules = builtins.readFile ./files/shared/global-rules.md;
  vaultContextMcp = inputs.vault-context.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # The tests only read these scripts. Keep the rest of the repository,
  # including the agent rule files, out of the check's inputs so unrelated
  # commits do not re-run them.
  testRepository = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ./files/sync-vault-context-runtime
      ./files/vault-git-sync
      ./files/project-context-init.py
    ];
  };
  vaultContextIntegrationCheck =
    pkgs.runCommand "vault-context-dotfiles-integration-check"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.git
          pkgs.jq
          pkgs.nodejs
          pkgs.python3
          pkgs.rsync
        ];
      }
      ''
        test -f ${vaultContextMcp}/share/vault-context-mcp/dist/src/server.js
        test -f ${vaultContextMcp}/share/vault-context-mcp/dist/src/cli.js
        test -f ${vaultContextMcp}/share/vault-context-mcp/dist/scripts/check-sensitive-stdin.js
        test -L ${vaultContextMcp}/share/vault-context-mcp/src/server.mjs
        test -L ${vaultContextMcp}/share/vault-context-mcp/scripts/migrate-v2.mjs
        test -x ${vaultContextMcp}/share/vault-context-mcp/bin/vault-context
        test -x ${vaultContextMcp}/share/vault-context-mcp/bin/vault-context-server
        DOTFILES_REPOSITORY=${testRepository} PYTHONDONTWRITEBYTECODE=1 python3 \
          ${./tests}/test_sync_vault_context_runtime.py -v
        DOTFILES_REPOSITORY=${testRepository} PYTHONDONTWRITEBYTECODE=1 python3 \
          ${./tests}/test_vault_git_sync.py -v
        DOTFILES_REPOSITORY=${testRepository} PYTHONDONTWRITEBYTECODE=1 python3 \
          ${./tests}/test_project_context_init.py -v
        touch "$out"
      '';
  vaultContextRuntime = pkgs.runCommand "vault-context-runtime" { } ''
    test -e ${vaultContextIntegrationCheck}
    mkdir -p "$out/share"
    ln -s ${vaultContextMcp}/share/vault-context-mcp \
      "$out/share/vault-context-mcp"
  '';
  syncRuntime = pkgs.writeShellApplication {
    name = "sync-vault-context-runtime";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.nodejs
      pkgs.rsync
      pkgs.sqlite
    ];
    text = ''
      export VAULT_CONTEXT_BUNDLE=${lib.escapeShellArg "${vaultContextRuntime}/share/vault-context-mcp"}
      exec ${pkgs.bash}/bin/bash ${./files/sync-vault-context-runtime} "$@"
    '';
  };
  vaultGitSync = pkgs.writeShellApplication {
    name = "vault-git-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
      pkgs.nodejs
      pkgs.openssh
      pkgs.sqlite
    ];
    text = builtins.readFile ./files/vault-git-sync;
  };
  # Both `.codex/bin/vault-context` and `.codex/bin/codex-context` use this wrapper.
  vaultContextCli = pkgs.writeShellApplication {
    name = "vault-context";
    runtimeInputs = [
      pkgs.nodejs
      pkgs.sqlite
    ];
    text = ''
      exec ${homeDir}/.codex/mcp/vault-context-mcp/bin/vault-context "$@"
    '';
  };
  projectContextInit = pkgs.writeShellApplication {
    name = "project-context-init";
    runtimeInputs = [
      pkgs.git
      pkgs.gitleaks
      pkgs.python3
    ];
    text = ''
      exec python3 ${./files/project-context-init.py} "$@"
    '';
  };
in
delib.module {
  name = "vault-context";

  options = delib.singleEnableOption hostTraits.macbook;

  home.ifEnabled = {
    home.file = {
      # Each agent gets the shared rules plus only its own runtime-specific section.
      ".codex/AGENTS.md" = {
        text = sharedRules + builtins.readFile ./files/codex/AGENTS.md;
        force = true;
      };
      ".claude/CLAUDE.md" = {
        text = sharedRules + builtins.readFile ./files/claude/CLAUDE.md;
        force = true;
      };
      # Antigravity and its CLI share this global customization root.
      ".gemini/config/AGENTS.md" = {
        text = sharedRules + builtins.readFile ./files/antigravity/AGENTS.md;
        force = true;
      };
      ".codex/project-context-protocol.md" = {
        source = ./files/codex/project-context-protocol.md;
        force = true;
      };
      ".codex/bin/vault-context" = {
        source = "${vaultContextCli}/bin/vault-context";
        executable = true;
      };
      ".codex/bin/codex-context" = {
        source = "${vaultContextCli}/bin/vault-context";
        executable = true;
      };
      ".local/bin/sync-vault-context-runtime" = {
        source = "${syncRuntime}/bin/sync-vault-context-runtime";
        executable = true;
      };
      ".local/bin/vault-git-sync" = {
        source = "${vaultGitSync}/bin/vault-git-sync";
        executable = true;
        force = true;
      };
      ".local/bin/project-context-init" = {
        source = "${projectContextInit}/bin/project-context-init";
        executable = true;
      };
    };

    home.activation.syncVaultContextRuntime = hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${syncRuntime}/bin/sync-vault-context-runtime
    '';
  };
}
