{
  delib,
  host,
  pkgs,
  profile,
  ...
}:
delib.module {
  name = "nixos.host.nvidia-desktop";

  options = delib.singleEnableOption (host.name == "nvidia-desktop");

  nixos.ifEnabled = {
    networking.hostName = "nvidia-desktop";
    networking.nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
    boot.kernelPackages = pkgs.linuxPackages_latest;

    programs.kdeconnect.enable = true;

    security.sudo.extraRules = [
      {
        users = [ profile.username ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
