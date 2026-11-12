{
  delib,
  hostTraits,
  ...
}:
delib.module {
  name = "fuzzel";

  options = delib.singleEnableOption hostTraits.linuxDesktop;

  home.ifEnabled = {
    xdg.configFile."fuzzel" = {
      source = ./files/config;
      recursive = true;
    };

    home.file.".local/bin/emoji-fuzzel" = {
      source = ./files/emoji-fuzzel;
      executable = true;
    };
  };
}
