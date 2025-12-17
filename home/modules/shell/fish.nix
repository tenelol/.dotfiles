{ config, pkgs, ... }:

{
  programs.fish = {
    enable = true;
    
  interactiveShellInit = ''
    set -g greetings "🥳Hollow World!🥳" "こにちは" "酒!暴力!Linux!"
    set -l count (count $greetings)
    set -l r (random)
    set -l idx (math "$r % $count + 1")
    set fish_greeting $greetings[$idx]
'';

    shellAliases = {
      ls = "eza --icons";
      deploy-mywebfw = "ssh -t homeserver '~/bin/deploy-mywebfw.sh'";
    };
  };
  
  xdg.configFile."fish/functions/fish_prompt.fish".source =
    ../../../config/fish/functions/fish_prompt.fish;

  xdg.configFile."fish/functions/fish_right_prompt.fish".source =
    ../../../config/fish/functions/fish_right_prompt.fish;

}

