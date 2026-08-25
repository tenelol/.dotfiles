{
  delib,
  host,
  ...
}:
delib.module {
  name = "perf-snapshot";

  options = delib.singleEnableOption (builtins.match ".*-linux" host.system != null);

  home.ifEnabled = {
    home.file.".local/bin/perf-snapshot" = {
      source = ./perf-snapshot/files/perf-snapshot;
      executable = true;
    };
  };
}
