{
  delib,
  hostTraits,
  hm,
  pkgs,
  profile,
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
    launchd.agents.memo-sync = {
      enable = true;
      config = {
        ProgramArguments = [
          "${memoSync}/bin/memo-sync"
          "watch"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        ThrottleInterval = 10;
        Umask = 63;
        StandardOutPath = "/Users/${profile.username}/Library/Logs/memo-sync.log";
        StandardErrorPath = "/Users/${profile.username}/Library/Logs/memo-sync.log";
      };
    };
    # Automator requires regular files, not Home Manager's file symlinks.
    home.activation.installMemoSyncService = hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./files/install_service.py} \
        --destination "$HOME/Library/Services/MemoSyncRegister.workflow" \
        --info ${./files/service-info.plist} \
        --workflow ${serviceWorkflow}
    '';
  };
}
