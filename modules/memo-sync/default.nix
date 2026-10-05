{
  delib,
  hostTraits,
  hm,
  pkgs,
  ...
}:
let
  memoSync = pkgs.writeShellApplication {
    name = "memo-sync";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./files/memo_sync.py} --bridge-path ${./files/notes.js} "$@"
    '';
  };
  serviceWorkflow = pkgs.writeText "memo-sync-register.wflow" (
    builtins.replaceStrings [ "@MEMO_SYNC@" ] [ "${memoSync}/bin/memo-sync" ] (
      builtins.readFile ./files/register.workflow.plist
    )
  );
in
delib.scopedModule {
  name = "memo-sync";
  scope = hostTraits.macbook;

  options = delib.singleEnableOption hostTraits.macbook;

  home.ifEnabled = {
    home.packages = [ memoSync ];
    # Automator requires regular files, not Home Manager's file symlinks.
    home.activation.installMemoSyncService = hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./files/install_service.py} \
        --destination "$HOME/Library/Services/MemoSyncRegister.workflow" \
        --info ${./files/service-info.plist} \
        --workflow ${serviceWorkflow}
    '';
  };
}
