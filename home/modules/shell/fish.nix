{ config, pkgs, ... }:

{
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set -g greetings "🥳Hollow World!🥳" "👏Welcome back!👏" "🚀Ready to code?🚀" "💡Let's be productive!💡" "💰Time is money!💰" "🔥Stay Hungry!🔥"
      set -l count (count $greetings)
      set -l r (random)
      set -l idx (math "$r % $count + 1")
      set fish_greeting $greetings[$idx]
    '';

    shellAliases = {
      ls = "eza --icons";
      deploy-portfolio = "ssh -t homeserver '~/bin/deploy-portfolio.sh'";
    };
  };

  xdg.configFile."fish/functions/fish_prompt.fish".source =
    ../../../config/fish/functions/fish_prompt.fish;

  xdg.configFile."fish/functions/fish_right_prompt.fish".source =
    ../../../config/fish/functions/fish_right_prompt.fish;

}
