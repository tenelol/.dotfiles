{
  delib,
  host,
  profile,
  ...
}:
delib.module {
  name = "nixos.host.nixos-server";

  options = delib.singleEnableOption (host.name == "nixos-server");

  nixos.ifEnabled = {
    networking.hostName = "nixos-server";

    users.users.${profile.username} = {
      openssh.authorizedKeys.keyFiles = [ profile.sshPublicKey ];
    };

    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    services.logind.settings = {
      Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };
    };

    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };
  };
}
