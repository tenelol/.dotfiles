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
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    programs.fish = {
      enable = true;
      plugins = [ fishLogoPlugin ];

      interactiveShellInit = ''
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
