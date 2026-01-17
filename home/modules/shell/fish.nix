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

      set -l ppid (ps -o ppid= -p $fish_pid | string trim)
      set -l parent (ps -o comm= -p $ppid | string trim)

      if set -q ZELLIJ; and test "$ZELLIJ" = "0"; and test "$parent" != "zellij"
        set -e ZELLIJ
      end

      if not set -q ZELLIJ; and not set -q INSIDE_ZELLIJ; and test "$parent" != "zellij"
        exec zellij
      end
    '';

    shellAliases = {
      ls = "eza --icons";
      deploy-portfolio = "ssh -t homeserver '~/bin/deploy-portfolio.sh'";
      niri-mirror = "niri msg output DP-3 on; niri msg output HDMI-A-1 on; niri msg output DP-3 mode 1920x1080@59.934; niri msg output HDMI-A-1 mode 1920x1080@59.934; niri msg output DP-3 scale 1.0; niri msg output HDMI-A-1 scale 1.0; niri msg output DP-3 position set 0 0; niri msg output HDMI-A-1 position set 0 0";
      niri-extend = "niri msg output DP-3 on; niri msg output HDMI-A-1 on; niri msg output DP-3 mode 3840x2160@60.000; niri msg output HDMI-A-1 mode 1920x1080@59.934; niri msg output DP-3 scale 1.5; niri msg output HDMI-A-1 scale 1.0; niri msg output DP-3 position set 0 0; niri msg output HDMI-A-1 position set 2560 0";
    };
  };

  xdg.configFile."fish/functions/fish_prompt.fish".source =
    ../../../config/fish/functions/fish_prompt.fish;

  xdg.configFile."fish/functions/fish_right_prompt.fish".source =
    ../../../config/fish/functions/fish_right_prompt.fish;

}
