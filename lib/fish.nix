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
        # Match the low-saturation Graphite Frost hierarchy used by Neovim.
        set -g fish_color_normal b3bbc7
        set -g fish_color_command d8dde6
        set -g fish_color_keyword 8993a3
        set -g fish_color_error c4a0e8
        set -g fish_color_param b3bbc7
        set -g fish_color_option 8993a3
        set -g fish_color_quote 8993a3
        set -g fish_color_redirection 7f9bc4
        set -g fish_color_end 8993a3
        set -g fish_color_operator 78b6cf
        set -g fish_color_escape 7f9bc4
        set -g fish_color_autosuggestion 4f5968
        set -g fish_color_comment 626c7a
        set -g fish_color_match 94b8c7
        set -g fish_color_selection b3bbc7 --background=293448
        set -g fish_color_search_match d8dde6 --background=202631
        set -g fish_color_cancel c4a0e8
        set -g fish_color_valid_path b3bbc7
        set -g fish_color_cwd 7f9bc4
        set -g fish_color_cwd_root c4a0e8
        set -g fish_color_user b3bbc7
        set -g fish_color_host 78b6cf
        set -g fish_color_host_remote a894c7
        set -g fish_color_status c4a0e8

        set -g fish_pager_color_progress 7f9bc4
        set -g fish_pager_color_prefix 78b6cf
        set -g fish_pager_color_completion b3bbc7
        set -g fish_pager_color_description 8993a3
        set -g fish_pager_color_selected_prefix 78b6cf --background=293448
        set -g fish_pager_color_selected_completion d8dde6 --background=293448
        set -g fish_pager_color_selected_description b3bbc7 --background=293448

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

        # Recall the last argument from command history with Esc, then period.
        bind --user escape,. history-last-token-search-backward
        bind --user -M insert escape,. history-last-token-search-backward

      '';

      shellAbbrs = {
        cc = "claude";
        cg = "clang";
        cx = "codex";
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
