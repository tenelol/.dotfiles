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
        PYTHONDONTWRITEBYTECODE=1 python3 \
          ${../config/codex/hooks}/tests/test_inject_vault_context_workflow.py -v
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
      exec ${pkgs.bash}/bin/bash ${../config/scripts/sync-vault-context-runtime} "$@"
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
    text = builtins.readFile ../config/scripts/vault-git-sync;
  };
  vaultContextCli = pkgs.writeShellApplication {
    name = "vault-context";
    runtimeInputs = [
      pkgs.nodejs
      pkgs.sqlite
    ];
    text = ''
      exec node /Users/tener/.codex/mcp/vault-context-mcp/src/cli.mjs "$@"
    '';
  };
  codexContextCli = pkgs.writeShellApplication {
    name = "codex-context";
    runtimeInputs = [
      pkgs.nodejs
      pkgs.sqlite
    ];
    text = ''
      exec node /Users/tener/.codex/mcp/vault-context-mcp/src/cli.mjs "$@"
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
        source = ../config/codex/hooks/inject-vault-context-workflow.py;
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
