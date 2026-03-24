{
  delib,
  host,
  hostLib,
  ...
}:
delib.module {
  name = "ghostty";

  options = delib.singleEnableOption (hostLib.isDesktop host);

  home.ifEnabled = {
    xdg.configFile."ghostty/config".source = ../config/ghostty/config;
  };
}
