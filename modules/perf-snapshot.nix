{
  delib,
  host,
  hostLib,
  ...
}:
delib.module {
  name = "perf-snapshot";

  options = delib.singleEnableOption (hostLib.isLinux host);

  home.ifEnabled = {
    home.file.".local/bin/perf-snapshot" = {
      source = ../config/scripts/perf-snapshot;
      executable = true;
    };
  };
}
