{
  delib,
  hm,
  host,
  lib,
  pkgs,
  ...
}:
let
  configureDockerDesktopUpdatePolicy = pkgs.writeShellApplication {
    name = "configure-docker-desktop-update-policy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      settings_file="$HOME/Library/Group Containers/group.com.docker/settings-store.json"

      # Avoid creating this file before Docker Desktop's first-run setup.
      if [ ! -f "$settings_file" ]; then
        exit 0
      fi

      if jq --exit-status '
        .DisableUpdate == true
        and .AutoDownloadUpdates == false
        and .SilentModulesUpdate == false
      ' "$settings_file" >/dev/null; then
        exit 0
      fi

      mode=$(/usr/bin/stat -f '%Lp' "$settings_file")
      temporary_file="$(mktemp "$settings_file.XXXXXX")"
      trap 'rm -f "$temporary_file"' EXIT

      jq '
        .DisableUpdate = true
        | .AutoDownloadUpdates = false
        | .SilentModulesUpdate = false
      ' "$settings_file" > "$temporary_file"
      /bin/chmod "$mode" "$temporary_file"
      mv "$temporary_file" "$settings_file"
      trap - EXIT
    '';
  };
in
delib.module {
  name = "darwin.homebrew";

  options = delib.singleEnableOption (
    builtins.match ".*-darwin" host.system != null && !host.isServer
  );

  darwin.ifEnabled = {
    homebrew = {
      enable = true;
      enableFishIntegration = true;

      taps = [
        {
          name = "homebrew-zathura/zathura";
          trusted = true;
        }
      ];

      brews = [
        "awscli"
        "bat"
        "cloudflared"
        "cloudflare-wrangler"
        "cmake"
        "coreutils"
        "cowsay"
        "dotnet"
        "eza"
        "fd"
        "findutils"
        "gawk"
        "gdrive"
        "gh"
        "gnu-sed"
        "gnu-tar"
        "go"
        "gomi"
        "grep"
        "homebrew-zathura/zathura/zathura"
        "homebrew-zathura/zathura/zathura-cb"
        "homebrew-zathura/zathura/zathura-djvu"
        "homebrew-zathura/zathura/zathura-pdf-mupdf"
        "homebrew-zathura/zathura/zathura-ps"
        "lazygit"
        "llvm"
        "lolcat"
        "make"
        "mas"
        "mysql"
        "node"
        "pi-coding-agent"
        "pkgconf"
        "platformio"
        "pnpm"
        "powershell"
        "prettier"
        "prettierd"
        "python@3.14"
        "ripgrep"
        "rust"
        "sqlite"
        "supabase"
        "swiftlint"
        "tre-command"
        "wget"
        "xcodegen"
        "yazi"
        "zig"
      ];

      onActivation = {
        autoUpdate = false;
        upgrade = false;
        cleanup = "check";
      };

      masApps = {
        "Apple Configurator" = 1037126344;
        GarageBand = 682658836;
        iMovie = 408981434;
        Keynote = 409183694;
        LINE = 539883307;
        Numbers = 409203825;
        Pages = 409201541;
        RunCat = 1429033973;
      };

      # Public macOS apps and fonts belong in Homebrew. Nix remains only for
      # repo-built tools and the nix-darwin/Home Manager control plane.
      casks = [
        "azookey"
        "blender"
        "claude"
        "codex"
        "chatgpt"
        "cursor"
        "font-caskaydia-cove-nerd-font"
        "font-fira-code"
        "font-fira-code-nerd-font"
        "font-hack"
        "font-jetbrains-mono"
        "font-jetbrains-mono-nerd-font"
        "font-material-symbols"
        "font-noto-color-emoji"
        "font-noto-sans-cjk"
        "ghostty"
        "google-chrome"
        "insomnia"
        "karabiner-elements"
        "markdown-preview"
        "notion"
        {
          # Temporary: Homebrew marks this cask deprecated because it does not
          # pass the macOS Gatekeeper check.
          name = "qutebrowser";
          args.no_quarantine = true;
        }
        "raycast"
        "tailscale-app"
        "thebrowsercompany-dia"
        "zed"
        "zen"
      ]
      ++ lib.optionals host.fullDesktopFeatured [
        "db-browser-for-sqlite"
        "discord"
        "docker-desktop"
        "microsoft-excel"
        "microsoft-onenote"
        "microsoft-powerpoint"
        "microsoft-word"
        "obsidian"
        "palmier-pro"
        "slack"
        "spotify"
        "steam"
        "visual-studio-code"
      ];
    };
  };

  home.ifEnabled = {
    home.activation.configureDockerDesktopUpdatePolicy = hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${configureDockerDesktopUpdatePolicy}/bin/configure-docker-desktop-update-policy
    '';

    home.activation.linkZathuraPlugins = hm.dag.entryAfter [ "writeBoundary" ] ''
      brew=/opt/homebrew/bin/brew

      if [ -x "$brew" ] && zathura_prefix="$($brew --prefix zathura 2>/dev/null)"; then
        plugin_dir="$zathura_prefix/lib/zathura"
        $DRY_RUN_CMD mkdir -p "$plugin_dir"

        for plugin in cb djvu pdf-mupdf ps; do
          if plugin_prefix="$($brew --prefix "zathura-$plugin" 2>/dev/null)"; then
            source="$plugin_prefix/lib$plugin.dylib"
            if [ -f "$source" ]; then
              $DRY_RUN_CMD ln -sfn "$source" "$plugin_dir/lib$plugin.dylib"
            fi
          fi
        done
      fi
    '';
  };
}
