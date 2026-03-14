{ delib, host, ... }:
delib.module {
  name = "nixos.host.nvidia-desktop";

  options = delib.singleEnableOption (host.name == "nvidia-desktop");

  nixos.ifEnabled = {
    networking.hostName = "nvidia-desktop";
    networking.nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };
}
