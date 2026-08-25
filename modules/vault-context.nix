{
  delib,
  hm,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  isMacbook = host.name == "macbook" && builtins.match ".*-darwin" host.system != null;
  vaultContextMcp = inputs.vault-context.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
        PYTHONDONTWRITEBYTECODE=1 python3 \
          ${./vault-context/files/codex/hooks}/tests/test_inject_vault_context_workflow.py -v
        PYTHONDONTWRITEBYTECODE=1 python3 \
          ${./vault-context/files/codex/hooks}/tests/test_vault_capture_gate_hooks.py -v
        PYTHONDONTWRITEBYTECODE=1 python3 \
          ${./vault-context/files/codex/hooks}/tests/test_enforce_worktree_layout.py -v
        DOTFILES_REPOSITORY=${../.} PYTHONDONTWRITEBYTECODE=1 python3 \
          ${../tests}/test_sync_vault_context_runtime.py -v
        DOTFILES_REPOSITORY=${../.} PYTHONDONTWRITEBYTECODE=1 python3 \
          ${../tests}/test_vault_git_sync.py -v
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
      exec ${pkgs.bash}/bin/bash ${./vault-context/files/sync-vault-context-runtime} "$@"
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
    text = builtins.readFile ./vault-context/files/vault-git-sync;
  };
  vaultContextCli = pkgs.writeShellApplication {
    name = "vault-context";
    runtimeInputs = [
      pkgs.nodejs
      pkgs.sqlite
    ];
    text = ''
      exec node /Users/tener/.codex/mcp/vault-context-mcp/dist/src/cli.js "$@"
    '';
  };
  codexContextCli = pkgs.writeShellApplication {
    name = "codex-context";
    runtimeInputs = [
      pkgs.nodejs
      pkgs.sqlite
    ];
    text = ''
      exec node /Users/tener/.codex/mcp/vault-context-mcp/dist/src/cli.js "$@"
    '';
  };
in
delib.module {
  name = "vault-context";

  options = delib.singleEnableOption isMacbook;

  home.ifEnabled = lib.mkIf isMacbook {
    home.packages = [ pkgs.sqlite ];

    home.file = {
      ".codex/bin/vault-context" = {
        source = "${vaultContextCli}/bin/vault-context";
        executable = true;
      };
      ".codex/bin/codex-context" = {
        source = "${codexContextCli}/bin/codex-context";
        executable = true;
      };
      ".codex/hooks/inject-vault-context-workflow.py" = {
        source = ./vault-context/files/codex/hooks/inject-vault-context-workflow.py;
      };
      ".codex/hooks/mark-vault-capture-gate.py" = {
        source = ./vault-context/files/codex/hooks/mark-vault-capture-gate.py;
      };
      ".codex/hooks/ensure-vault-capture-gate.py" = {
        source = ./vault-context/files/codex/hooks/ensure-vault-capture-gate.py;
      };
      ".codex/hooks/enforce-worktree-layout.py" = {
        source = ./vault-context/files/codex/hooks/enforce-worktree-layout.py;
      };
      ".local/bin/sync-vault-context-runtime" = {
        source = "${syncRuntime}/bin/sync-vault-context-runtime";
        executable = true;
      };
      ".local/bin/vault-git-sync" = {
        source = "${vaultGitSync}/bin/vault-git-sync";
        executable = true;
      };
    };

    home.activation.syncVaultContextRuntime = hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${syncRuntime}/bin/sync-vault-context-runtime
    '';
  };
}
