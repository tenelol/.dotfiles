{
  delib,
  host,
  ...
}:
delib.module {
  name = "fuzzel";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-linux" host.system != null
  );

  home.ifEnabled = {
    xdg.configFile."fuzzel" = {
      source = ./fuzzel/files/config;
      recursive = true;
    };

    home.file.".local/bin/emoji-fuzzel" = {
      source = ./fuzzel/files/emoji-fuzzel;
      executable = true;
    };
  };
}
