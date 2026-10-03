{
  delib,
  host,
  lib,
  ...
}:
delib.module {
  name = "host-policy";

  myconfig.always.args.shared.hostTraits = rec {
    linux = lib.hasSuffix "-linux" host.system;
    darwin = lib.hasSuffix "-darwin" host.system;
    desktop = !host.isServer;
    linuxDesktop = desktop && linux;
    darwinDesktop = desktop && darwin;
    macbook = host.name == "macbook" && darwin;
  };
}
