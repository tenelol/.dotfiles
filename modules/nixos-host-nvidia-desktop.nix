{ delib, host, ... }:
delib.module {
  name = "nixos.host.nvidia-desktop";

  options = delib.singleEnableOption (host.name == "nvidia-desktop");

  nixos.ifEnabled = {
    networking.hostName = "nvidia-desktop";
    networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
    networking.extraHosts = ''
      185.199.108.133 release-assets.githubusercontent.com
      185.199.109.133 release-assets.githubusercontent.com
      185.199.110.133 release-assets.githubusercontent.com
      185.199.111.133 release-assets.githubusercontent.com
    '';
  };
}
