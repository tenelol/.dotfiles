{
  delib,
  lib,
  pkgs,
  profile,
  ...
}:
let
  iniadGitName = "1F10250179";
  iniadGitEmail = "s1F102501798@iniad.org";
  iniadGithubUser = iniadGitName;
  iniadSshKey = "~/.ssh/id_ed25519_iniad";
  realGh = lib.getExe pkgs.gh;
in
delib.module {
  name = "git";

  home.always = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."github.com-iniad" = {
        hostname = "github.com";
        user = "git";
        identityFile = iniadSshKey;
        identitiesOnly = true;
        addKeysToAgent = "yes";
      };
    };

    programs.git = {
      enable = true;
      includes = [
        {
          condition = "gitdir:~/iniad/";
          path = "~/.config/git/iniad";
        }
      ];
      settings = {
        user.name = profile.gitName;
        user.email = profile.gitEmail;
        core.editor = "nvim";
        init.defaultBranch = "main";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        credential.helper = "osxkeychain";
      };
    };

    xdg.configFile."git/iniad".text = ''
      [user]
        name = ${iniadGitName}
        email = ${iniadGitEmail}

      [url "git@github.com-iniad:"]
        insteadOf = git@github.com:
        insteadOf = https://github.com/

      [url "ssh://git@github.com-iniad/"]
        insteadOf = ssh://git@github.com/
    '';

    home.file.".local/bin/gh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        set -eo pipefail

        real_gh=${lib.escapeShellArg realGh}
        iniad_root="$HOME/iniad"
        iniad_gh_config_dir="$HOME/.config/gh-iniad"

        cwd="$(pwd -P 2>/dev/null || pwd)"
        in_iniad=0
        case "$cwd/" in
          "$iniad_root/"*) in_iniad=1 ;;
        esac

        if [ "$in_iniad" = 1 ] && [ -z "''${GH_CONFIG_DIR-}" ]; then
          export GH_CONFIG_DIR="$iniad_gh_config_dir"
        fi

        exec "$real_gh" "$@"
      '';
    };

    home.file.".local/bin/iniad-github-setup" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        set -eo pipefail

        real_gh=${lib.escapeShellArg realGh}
        iniad_github_user=${lib.escapeShellArg iniadGithubUser}
        gh_config_dir="$HOME/.config/gh-iniad"
        key_path="$HOME/.ssh/id_ed25519_iniad"
        key_comment=${lib.escapeShellArg iniadGitEmail}

        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        mkdir -p "$gh_config_dir"

        if ! GH_CONFIG_DIR="$gh_config_dir" "$real_gh" auth token --hostname github.com --user "$iniad_github_user" >/dev/null 2>&1; then
          echo "Opening browser login for the INIAD GitHub account: $iniad_github_user" >&2
          GH_CONFIG_DIR="$gh_config_dir" "$real_gh" auth login --web --hostname github.com --git-protocol ssh --skip-ssh-key
        fi

        if ! GH_CONFIG_DIR="$gh_config_dir" "$real_gh" auth switch --hostname github.com --user "$iniad_github_user"; then
          echo "gh is not authenticated as the INIAD account: $iniad_github_user" >&2
          echo "Run this again and choose the INIAD account in the browser login." >&2
          exit 1
        fi

        if [ ! -f "$key_path" ]; then
          ssh-keygen -t ed25519 -f "$key_path" -C "$key_comment"
        fi

        read -r key_type key_body _ < "$key_path.pub"
        public_key="$key_type $key_body"

        if GH_CONFIG_DIR="$gh_config_dir" "$real_gh" api user/keys --jq '.[].key' | grep -Fxq "$public_key"; then
          echo "SSH key is already registered on GitHub."
        else
          GH_CONFIG_DIR="$gh_config_dir" "$real_gh" ssh-key add "$key_path.pub" --title "$(hostname)-iniad"
        fi

        echo "Testing github.com-iniad SSH alias..."
        ssh -T github.com-iniad || true
      '';
    };
  };
}
