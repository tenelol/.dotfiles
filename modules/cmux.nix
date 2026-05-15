{ delib, host, ... }:
delib.module {
  name = "cmux";

  options = delib.singleEnableOption (
    builtins.match ".*-darwin" host.system != null && !host.isServer
  );

  home.ifEnabled = {
    xdg.configFile."cmux/cmux.json" = {
      force = true;
      text = ''
        {
          "$schema": "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json",
          "schemaVersion": 1,
          "app": {
            "preferredEditor": "nvim",
            "openSupportedFilesInCmux": false
          }
        }
      '';
    };
  };
}
