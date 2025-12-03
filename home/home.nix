  { pkgs, ...}:
  {
    home.username = "tener";
    home.homeDirectory = "/home/tener";
    home.stateVersion = "25.05";
    home.enableNixpkgsReleaseCheck = false;
    xdg.enable = true;

    home.packages = with pkgs; [
      hyprland kitty eww gh hyprpaper waybar firefox
      google-chrome wofi floorp-bin grim slurp
      wl-clipboard eza bat tre-command imv
    ];

    imports = [
      ./modules/shell/fish.nix
      ./modules/git.nix
      ./modules/nvim.nix
    ];


  }
