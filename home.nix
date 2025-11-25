  { pkgs, ...}
  {
    home.username = "tener";
    home.homeDirectory = "/home/tener";
    home.stateVersion = "25.05";
  };

    programs.git = {
      enable = true;
      userName = "tenelol"
      userEmail = "matsuda319@icloud.com"
      extraConfig.core.editore = "nvim";
  };

    home.packages = with pkgs; [
      neovim
  ];

