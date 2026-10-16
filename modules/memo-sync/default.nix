{
  delib,
  hostTraits,
  hm,
  pkgs,
  profile,
  ...
}:
let
  python = pkgs.python3.withPackages (ps: [
    ps.mistune
    ps.beautifulsoup4
    ps.markdownify
  ]);
  memoSync = pkgs.writeShellApplication {
    name = "memo-sync";
    runtimeInputs = [ python ];
    text = ''
      exec python3 ${./files}/memo_sync.py --bridge-path ${./files/notes.js} "$@"
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
    programs.nixvim.extraConfigLua = ''
      dofile("${./files/neovim.lua}").setup(nil, "${memoSync}/bin/memo-sync", {
        "/bin/launchctl", "kickstart", "gui/" .. vim.uv.getuid() .. "/org.nix-community.home.memo-sync",
      })
    '';
    launchd.agents.memo-sync = {
      enable = true;
      config = {
        ProgramArguments = [
          "${python}/bin/python3"
          "${./files}/memo_sync.py"
          "--bridge-path"
          "${./files/notes.js}"
          "watch"
          "--until-idle"
          "30"
        ];
        # Neovim starts the watcher on demand; it exits 30 seconds after Neovim stops using memo.
        RunAtLoad = false;
        KeepAlive = false;
        ProcessType = "Background";
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
