{ config, pkgs, ... }:

{
  programs.git.settings = {
      enable = true;
      userName = "tenelol";
      userEmail = "matsuda319@icloud.com";
      extraConfig.core.editor = "nvim";
    };

}
