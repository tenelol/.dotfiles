{
  delib,
  host,
  hostLib,
  ...
}:
delib.module {
  name = "nvim-web";

  options = delib.singleEnableOption (hostLib.isDesktop host);

  home.ifEnabled = {
    home.sessionVariables = {
      NVIM_WEB_WORKFLOW = "1";
    };
  };
}
