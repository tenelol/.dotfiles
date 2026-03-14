{ delib, ... }:
delib.module {
  name = "shell.fish";

  home.always = {
    programs.fish = {
      enable = true;

      interactiveShellInit = ''
        set -g greetings "🥳Hollow World!🥳" "👏Welcome back!👏" "🚀Ready to code?🚀" "💡Let's be productive!💡" "💰Time is money!💰" "🔥Stay Hungry!🔥"
        set -l count (count $greetings)
        set -l r (random)
        set -l idx (math "$r % $count + 1")
        set fish_greeting $greetings[$idx]

        if not contains /run/wrappers/bin $PATH
          set -gx PATH /run/wrappers/bin $PATH
        else if test "$PATH[1]" != /run/wrappers/bin
          set -gx PATH /run/wrappers/bin (string match -v /run/wrappers/bin $PATH)
        end

        fish_add_path ~/.opencode/bin

      '';

      shellAliases = {
        ls = "eza --icons";
      };
    };

    xdg.configFile."fish/functions/fish_prompt.fish".source =
      ../../config/fish/functions/fish_prompt.fish;

    xdg.configFile."fish/functions/fish_right_prompt.fish".source =
      ../../config/fish/functions/fish_right_prompt.fish;
  };
}
