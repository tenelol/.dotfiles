{ delib, pkgs, ... }:
let
  fishLogoPlugin = {
    name = "fish_logo";
    src = pkgs.fetchFromGitHub {
      owner = "laughedelic";
      repo = "fish_logo";
      rev = "dc6a40836de8c24c62ad7c4365aa9f21292c3e6e";
      hash = "sha256-DZXQt0fa5LdbJ4vPZFyJf5FWB46Dbk58adpHqbiUmyY=";
    };
  };
in
delib.module {
  name = "shell.fish";

  home.always = {
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
      plugins = [ fishLogoPlugin ];

      interactiveShellInit = ''
        # Keep interactive syntax highlighting on the white/blue palette.
        set -g fish_color_normal ffffff
        set -g fish_color_command 7aa2f7
        set -g fish_color_keyword 7aa2f7
        set -g fish_color_error ffffff
        set -g fish_color_param ffffff
        set -g fish_color_option ffffff
        set -g fish_color_quote ffffff
        set -g fish_color_redirection 7aa2f7
        set -g fish_color_end ffffff
        set -g fish_color_operator 7aa2f7
        set -g fish_color_escape 7aa2f7
        set -g fish_color_autosuggestion 7aa2f7
        set -g fish_color_comment ffffff
        set -g fish_color_match 7aa2f7
        set -g fish_color_selection ffffff --background=364a82
        set -g fish_color_search_match ffffff --background=364a82
        set -g fish_color_cancel ffffff
        set -g fish_color_valid_path ffffff
        set -g fish_color_cwd ffffff
        set -g fish_color_cwd_root ffffff
        set -g fish_color_user ffffff
        set -g fish_color_host ffffff
        set -g fish_color_host_remote ffffff
        set -g fish_color_status ffffff

        set -g fish_pager_color_progress 7aa2f7
        set -g fish_pager_color_prefix 7aa2f7
        set -g fish_pager_color_completion ffffff
        set -g fish_pager_color_description ffffff
        set -g fish_pager_color_selected_prefix 7aa2f7 --background=364a82
        set -g fish_pager_color_selected_completion ffffff --background=364a82
        set -g fish_pager_color_selected_description ffffff --background=364a82

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

    xdg.configFile."fish/functions/fish_prompt.fish".source =
      ../../config/fish/functions/fish_prompt.fish;

    xdg.configFile."fish/functions/fish_greeting.fish".source =
      ../../config/fish/functions/fish_greeting.fish;

    xdg.configFile."fish/functions/fish_right_prompt.fish".source =
      ../../config/fish/functions/fish_right_prompt.fish;
  };
}
