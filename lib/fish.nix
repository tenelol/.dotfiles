{ ... }:
{
  homeConfig = {
    programs.fzf = {
      enable = true;
      enableFishIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
      options = [
        "--cmd"
        "cd"
      ];
    };

    programs.fish = {
      enable = true;

      interactiveShellInit = ''
        # Match the terminal/Neovim TokyoNight palette while keeping errors obvious.
        set -g fish_color_normal c0caf5
        set -g fish_color_command 7dcfff
        set -g fish_color_keyword bb9af7
        set -g fish_color_error f7768e
        set -g fish_color_param c0caf5
        set -g fish_color_option e0af68
        set -g fish_color_quote 9ece6a
        set -g fish_color_redirection bb9af7
        set -g fish_color_end ff9e64
        set -g fish_color_operator 7dcfff
        set -g fish_color_escape bb9af7
        set -g fish_color_autosuggestion 565f89
        set -g fish_color_comment 565f89
        set -g fish_color_match e0af68
        set -g fish_color_selection c0caf5 --background=364a82
        set -g fish_color_search_match 1f2335 --background=e0af68
        set -g fish_color_cancel f7768e
        set -g fish_color_valid_path 9ece6a
        set -g fish_color_cwd 7aa2f7
        set -g fish_color_cwd_root f7768e
        set -g fish_color_user bb9af7
        set -g fish_color_host 7dcfff
        set -g fish_color_host_remote e0af68
        set -g fish_color_status f7768e

        set -g fish_pager_color_progress 7aa2f7
        set -g fish_pager_color_prefix 7dcfff
        set -g fish_pager_color_completion c0caf5
        set -g fish_pager_color_description 9aa5ce
        set -g fish_pager_color_selected_prefix 7dcfff --background=364a82
        set -g fish_pager_color_selected_completion c0caf5 --background=364a82
        set -g fish_pager_color_selected_description c0caf5 --background=364a82

        if test -d /run/wrappers/bin
          if not contains /run/wrappers/bin $PATH
            set -gx PATH /run/wrappers/bin $PATH
          else if test "$PATH[1]" != /run/wrappers/bin
            set -gx PATH /run/wrappers/bin (string match -v /run/wrappers/bin $PATH)
          end
        end

        fish_add_path ~/.opencode/bin

        if test -f ~/miniconda3/etc/fish/conf.d/conda.fish
          source ~/miniconda3/etc/fish/conf.d/conda.fish
        else if test -x ~/miniconda3/bin/conda
          eval (~/miniconda3/bin/conda shell.fish hook)
        end

        if test -f ~/.config/fish/secrets.fish
          source ~/.config/fish/secrets.fish
        end

      '';

      shellAliases = {
        ls = "eza --icons";
        rm = "gomi";
        tm = "tmux new-session -A -s main";
      };
    };

    xdg.configFile."fish/functions/fish_prompt.fish".source = ../config/fish/functions/fish_prompt.fish;

    xdg.configFile."fish/functions/fish_greeting.fish".source =
      ../config/fish/functions/fish_greeting.fish;

    xdg.configFile."fish/functions/fish_right_prompt.fish".source =
      ../config/fish/functions/fish_right_prompt.fish;
  };
}
