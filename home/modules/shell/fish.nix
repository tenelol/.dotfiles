{ config, pkgs, ... }:

{
  programs.fish = {
    enable = true;
    
    interactiveShellInit = ''
      set fish_greeting "🥳Hollow World!🥳"
    '';
    shellAliases = {
      ls = "eza --icons";
      deploy-mywebfw = "ssh -t homeserver '~/bin/deploy-mywebfw.sh'";
    };
  };
  
  xdg.configFile."fish/functions/fish_prompt.fish".source =
    ../../../fish/functions/fish_prompt.fish;

  xdg.configFile."fish/functions/fish_right_prompt.fish".source =
    ../../../fish/functions/fish_right_prompt.fish;

}

