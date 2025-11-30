{ config, pkgs, ... }:

{
  programs.fish = {
    enable = true;

    shellAliases = {
      ls = "eza --icons";
    };
  };
  
  xdg.configFile."fish/functions/fish_prompt.fish".source =
    ../../fish/functions/fish_prompt.fish;

  xdg.configFile."fish/functions/fish_right_prompt.fish".source =
    ../../fish/functions/fish_right_prompt.fish;

}

