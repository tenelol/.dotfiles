  { pkgs, ...}:
  {
    home.username = "tener";
    home.homeDirectory = "/home/tener";
    home.stateVersion = "25.05";
    home.enableNixpkgsReleaseCheck = false;
    xdg.enable = true;


#programs.git.settings = {
 #     enable = true;
  #    userName = "tenelol";
   #   userEmail = "matsuda319@icloud.com";
    #  extraConfig.core.editor = "nvim";
    #};

    home.packages = with pkgs; [
      hyprland kitty eww gh hyprpaper waybar firefox google-chrome wofi floorp-bin grim slurp wl-clipboard eza bat tre-command
    ];

    import = [
   #   ./modules/shell/fish.nix
      ./modules/git.nix
    ];


  }
