{ delib, host, ... }:
delib.module {
  name = "ushi";

  options = delib.singleEnableOption (!(host.isServer or false));

  home.ifEnabled.home.file.".local/bin/ushi" = {
    source = ./files/ushi;
    executable = true;
  };
}
