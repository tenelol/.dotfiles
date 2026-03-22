{ delib, host, ... }:
delib.module {
  name = "nvim-web";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    home.sessionVariables = {
      NVIM_WEB_WORKFLOW = "1";
    };
  };
}
