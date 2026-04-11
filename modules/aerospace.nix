{
  delib,
  host,
  ...
}:
delib.module {
  name = "aerospace";

  options = delib.singleEnableOption (
    !host.isServer && builtins.match ".*-darwin" host.system != null
  );

  darwin.ifEnabled = {
    homebrew = {
      taps = [ "nikitabobko/tap" ];
      casks = [ "nikitabobko/tap/aerospace" ];
    };
  };

  home.ifEnabled = {
    home.file.".aerospace.toml".source = ../config/aerospace/aerospace.toml;
  };
}
