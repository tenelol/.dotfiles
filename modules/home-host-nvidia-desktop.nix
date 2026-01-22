{ delib, host, ... }:
delib.module {
  name = "home.host.nvidia-desktop";

  options = delib.singleEnableOption (host.name == "nvidia-desktop");

  home.ifEnabled = {
    home.sessionVariables = {
      NVIM_DISCORD_PRESENCE = "1";
    };
  };
}
