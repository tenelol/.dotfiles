{
  delib,
  hostTraits,
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
in
delib.scopedModule {
  name = "memo-sync";
  scope = hostTraits.macbook;

  options = delib.singleEnableOption hostTraits.macbook;

  home.ifEnabled = {
    home.packages = [ memoSync ];
    home.file = {
      "Library/Services/MemoSyncRegister.workflow/Contents/Info.plist".source =
        ./files/service-info.plist;
      "Library/Services/MemoSyncRegister.workflow/Contents/document.wflow".text =
        builtins.replaceStrings [ "@MEMO_SYNC@" ] [ "${memoSync}/bin/memo-sync" ]
          (builtins.readFile ./files/register.workflow.plist);
    };
  };
}
