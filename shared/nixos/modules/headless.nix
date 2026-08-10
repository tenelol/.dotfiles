{ config, lib, ... }:
let
  cfg = config.tenelol.headless;
in
{
  options.tenelol.headless.enable = lib.mkEnableOption "headless power management defaults";

  config = lib.mkIf cfg.enable {
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
    };

    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };
  };
}
