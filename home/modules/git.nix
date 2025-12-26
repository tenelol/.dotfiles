{ config, pkgs, ... }:

{
  programs.git.settings = {
      enable = true;
      userName = "tenelol";
      userEmail = "tenelol@tenelol.dev";
      extraConfig.core.editor = "nvim";
    };

}
