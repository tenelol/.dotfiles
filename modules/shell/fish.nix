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
        niri-mirror = "niri msg output DP-3 on; niri msg output HDMI-A-1 on; niri msg output DP-3 mode 1920x1080@59.934; niri msg output HDMI-A-1 mode 1920x1080@59.934; niri msg output DP-3 scale 1.0; niri msg output HDMI-A-1 scale 1.0; niri msg output DP-3 position set 0 0; niri msg output HDMI-A-1 position set 0 0";
        niri-extend = "niri msg output DP-3 on; niri msg output HDMI-A-1 on; niri msg output DP-3 mode 3840x2160@75.000; niri msg output HDMI-A-1 mode 1920x1080@164.995; niri msg output DP-3 scale 1.5; niri msg output HDMI-A-1 scale 1.0; niri msg output DP-3 position set 0 0; niri msg output HDMI-A-1 position set 2560 540";
      };
    };

    xdg.configFile."fish/functions/fish_prompt.fish".source =
      ../../config/fish/functions/fish_prompt.fish;

    xdg.configFile."fish/functions/fish_right_prompt.fish".source =
      ../../config/fish/functions/fish_right_prompt.fish;
  };
}
