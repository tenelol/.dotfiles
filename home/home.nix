  { pkgs, ...}:
  {
    home.username = "tener";
    home.homeDirectory = "/home/tener";
    home.stateVersion = "25.05";
    home.enableNixpkgsReleaseCheck = false;

    home.packages = with pkgs; [
      kitty eww gh waybar
      wofi floorp-bin sqlitebrowser
      eza bat tre-command imv ripgrep
    ];

    imports = [
      ./modules/shell/fish.nix
      ./modules/git.nix
      ./modules/nvim.nix
      ./modules/hypr.nix
    ];


  }
