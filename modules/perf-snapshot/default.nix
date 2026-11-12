{
  delib,
  hostTraits,
  ...
}:
delib.module {
  name = "perf-snapshot";

  options = delib.singleEnableOption hostTraits.linux;

  home.ifEnabled = {
    home.file.".local/bin/perf-snapshot" = {
      source = ./files/perf-snapshot;
      executable = true;
    };
  };
}
