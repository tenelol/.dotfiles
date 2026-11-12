{ delib, hostTraits, ... }:
delib.module {
  name = "ushi";

  options = delib.singleEnableOption hostTraits.desktop;

  home.ifEnabled.home.file.".local/bin/ushi" = {
    source = ./files/ushi;
    executable = true;
  };
}
