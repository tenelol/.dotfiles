{
  delib,
  host,
  hostLib,
  ...
}:
delib.module {
  name = "fuzzel";

  options = delib.singleEnableOption (hostLib.isLinuxDesktop host);

  home.ifEnabled = {
    xdg.configFile."fuzzel" = {
      source = ../config/fuzzel;
      recursive = true;
    };
  };
}
