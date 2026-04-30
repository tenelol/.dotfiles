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
        iniad_github_user=${lib.escapeShellArg iniadGithubUser}
        iniad_root="$HOME/iniad"

        cwd="$(pwd -P 2>/dev/null || pwd)"
        in_iniad=0
        case "$cwd/" in
          "$iniad_root/"*) in_iniad=1 ;;
        esac

        if [ "$in_iniad" = 1 ] && [ -z "$GH_TOKEN" ] && [ -z "$GITHUB_TOKEN" ]; then
          case "''${1-}" in
            "" | "-h" | "--help" | "--version" | "help" | "version" | "completion" | "config")
              exec "$real_gh" "$@"
              ;;
          esac

          if [ "$1" = "auth" ] && [ "''${2-}" != "status" ] && [ "''${2-}" != "token" ]; then
            exec "$real_gh" "$@"
          fi

          token="$("$real_gh" auth token --hostname github.com --user "$iniad_github_user" 2>/dev/null || true)"
          if [ -z "$token" ]; then
            cat >&2 <<EOF
        gh: INIAD GitHub account '$iniad_github_user' is not authenticated.
        Run one of:
          $real_gh auth login --hostname github.com --git-protocol ssh --skip-ssh-key
          iniad-github-setup
        EOF
            exit 1
          fi

          export GH_TOKEN="$token"
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
        key_path="$HOME/.ssh/id_ed25519_iniad"
        key_comment=${lib.escapeShellArg iniadGitEmail}

        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"

        if [ ! -f "$key_path" ]; then
          ssh-keygen -t ed25519 -f "$key_path" -C "$key_comment"
        fi

        if ! "$real_gh" auth token --hostname github.com --user "$iniad_github_user" >/dev/null 2>&1; then
          echo "Log in with the INIAD GitHub account: $iniad_github_user" >&2
          "$real_gh" auth login --hostname github.com --git-protocol ssh --skip-ssh-key
        fi

        token="$("$real_gh" auth token --hostname github.com --user "$iniad_github_user")"
        read -r key_type key_body _ < "$key_path.pub"
        public_key="$key_type $key_body"

        if GH_TOKEN="$token" "$real_gh" api user/keys --jq '.[].key' | grep -Fxq "$public_key"; then
          echo "SSH key is already registered on GitHub."
        else
          GH_TOKEN="$token" "$real_gh" ssh-key add "$key_path.pub" --title "$(hostname)-iniad"
        fi

        echo "Testing github.com-iniad SSH alias..."
        ssh -T github.com-iniad || true
      '';
    };
  };
}
