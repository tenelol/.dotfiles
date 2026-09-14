{
  delib,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
let
  isDarwinDesktop = !host.isServer && builtins.match ".*-darwin" host.system != null;
  codexNotionToken = pkgs.writeShellApplication {
    name = "codex-notion-token";
    text = ''
      service='dev.tenelol.codex.notion-token'
      account='${profile.username}'

      usage() {
        cat <<EOF
      Usage: codex-notion-token <set|apply|status|delete>

        set     Store or update the Notion token in macOS Keychain, then load it
        apply   Load NOTION_TOKEN from Keychain into the user launchd environment
        status  Report whether the Keychain item and launchd environment are set
        delete  Remove the Keychain item and unset NOTION_TOKEN from launchd
      EOF
      }

      find_token() {
        /usr/bin/security find-generic-password -a "$account" -s "$service" -w 2>/dev/null
      }

      apply_token() {
        token="$(find_token)" || {
          echo "No Notion token found in Keychain. Run: codex-notion-token set" >&2
          exit 1
        }

        if [ -z "$token" ]; then
          echo "Keychain item exists but the Notion token is empty. Run: codex-notion-token set" >&2
          exit 1
        fi

        /bin/launchctl setenv NOTION_TOKEN "$token"
      }

      set_token() {
        echo "Store Notion token in Keychain item: $service" >&2
        echo "The token input is handled by /usr/bin/security and is not printed." >&2
        /usr/bin/security add-generic-password \
          -U \
          -a "$account" \
          -s "$service" \
          -l "Codex Notion token" \
          -D "application password" \
          -T /usr/bin/security \
          -w

        apply_token
        echo "Notion token saved to Keychain and loaded into launchd." >&2
        echo "Restart Codex so it inherits NOTION_TOKEN." >&2
      }

      status_token() {
        if find_token >/dev/null; then
          echo "Keychain item: present"
        else
          echo "Keychain item: missing"
        fi

        launchd_token="$(/bin/launchctl getenv NOTION_TOKEN 2>/dev/null || true)"
        if [ -n "$launchd_token" ]; then
          echo "launchd NOTION_TOKEN: set"
        else
          echo "launchd NOTION_TOKEN: unset"
        fi
      }

      delete_token() {
        /usr/bin/security delete-generic-password -a "$account" -s "$service" >/dev/null 2>&1 || true
        /bin/launchctl unsetenv NOTION_TOKEN
        echo "Notion token removed from Keychain and launchd." >&2
      }

      case "''${1:-status}" in
        set)
          set_token
          ;;
        apply)
          apply_token
          ;;
        status)
          status_token
          ;;
        delete)
          delete_token
          ;;
        -h|--help|help)
          usage
          ;;
        *)
          usage >&2
          exit 64
          ;;
      esac
    '';
  };
in
delib.module {
  name = "codex-notion-token";

  options = delib.singleEnableOption isDarwinDesktop;

  darwin.ifEnabled = lib.mkIf isDarwinDesktop {
    launchd.user.agents.codex-notion-token = {
      serviceConfig = {
        ProgramArguments = [
          "${codexNotionToken}/bin/codex-notion-token"
          "apply"
        ];
        RunAtLoad = true;
        KeepAlive = false;
        ProcessType = "Background";
      };

      managedBy = "codex-notion-token";
    };
  };

  home.ifEnabled = lib.mkIf isDarwinDesktop {
    home.file.".local/bin/codex-notion-token" = {
      source = "${codexNotionToken}/bin/codex-notion-token";
      executable = true;
    };
  };
}
