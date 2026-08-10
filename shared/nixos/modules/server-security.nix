{
  config,
  lib,
  ...
}:
let
  cfg = config.tenelol.serverSecurity;
in
{
  options.tenelol.serverSecurity = {
    enable = lib.mkEnableOption "the shared headless server security policy";
    adminUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users allowed to connect over SSH and administer the server.";
    };
    authorizedKeyFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Public SSH key files installed for each administrator.";
    };
    passwordlessSudo = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow administrators to use sudo without a password.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.enable = true;

    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        AllowUsers = cfg.adminUsers;
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    users.users = lib.genAttrs cfg.adminUsers (_: {
      openssh.authorizedKeys.keyFiles = cfg.authorizedKeyFiles;
    });

    security.sudo.extraRules = lib.optionals cfg.passwordlessSudo (
      map (user: {
        users = [ user ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }) cfg.adminUsers
    );
  };
}
