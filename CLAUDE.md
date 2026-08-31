## Repository context
- This directory is a personal `denix`-based dotfiles repository.
- It manages NixOS and `nix-darwin` hosts from one flake.
- Home Manager is integrated into the system configurations, not exposed as standalone `homeConfigurations`.
- This repo is optimized for the owner's machines and workflow, not as a generic starter template.

## Repository workflow
- Run CI-style Nix validation, host builds, and switches only when explicitly requested.
- Prefer `nh` commands over raw `nixos-rebuild` / `darwin-rebuild` unless the user explicitly asks otherwise.
- Preferred validation command when explicitly requested: `nix flake check --all-systems --no-build`
- Preferred Linux build commands:
  - `nh os build . -H adguard-home`
  - `nh os build . -H surface`
  - `nh os build . -H nvidia-desktop`
  - `nh os build . -H web-server`
  - `nh os build . -H nas`
  - `nh os build . -H wsl`
- Preferred Darwin build command:
  - `nh darwin build . -H macbook-rift`
- Preferred switch commands mirror the build commands with `switch` instead of `build`.
- For rebuild/switch on rice-enabled hosts, preserve the active rice by targeting the rice-specific configuration. On `macbook`, infer the active rice from the current desktop state, such as the AeroSpace process/config or active wallpaper, and prefer names such as `macbook-rift` or `macbook-aerospace` instead of bare `macbook`.
- Before running any rebuild/switch command, check that another `nh ... build`, `nh ... switch`, `darwin-rebuild`, or `nixos-rebuild` process is not already running. If one is active, do not start a conflicting activation.
- Run a matching `nh ... switch` only when explicitly requested.
- Create a commit only when explicitly requested.

## denix structure
- `hosts/<name>/default.nix` should stay thin: host metadata plus hardware imports.
- Shared and host-specific behavior belongs in `modules/`.
- Integrated Home Manager behavior belongs in each denix module's `home.*` sections.
- Deployed non-Nix sources belong in the owning `modules/<feature>/files/` directory; package-owned sources belong beside their package definition.
- `denix` recursively auto-discovers `.nix` files in `hosts/`, `modules/`, and `rices/`, so local denix modules do not need manual imports and new `.nix` files must be committed to Git.
- Keep imports for external modules, generated hardware modules, and deliberate reusable-module boundaries.

## Directory layout
- `flake.nix`: flake entrypoint; uses `denix.lib.configurations` to wire hosts and modules.
- `hosts/`: thin per-host definitions (metadata + hardware import only).
- `modules/`: denix auto-discovered shared and host-specific modules, with module-owned non-Nix assets under `files/`.
- `rices/`: denix rice definitions (currently minimal — common wallpaper switching).
- `packages/`: lightweight custom package definitions.

## Host inventory
- `adguard-home`: x86_64-linux Proxmox guest config; VM stays stopped until router/DHCP integration is safe
- `surface`: x86_64-linux laptop
- `nvidia-desktop`: x86_64-linux desktop
- `web-server`: x86_64-linux Proxmox guest for personal sites
- `nas`: x86_64-linux Proxmox guest configuration; deployment waits for the data HDD
- `wsl`: x86_64-linux NixOS-WSL environment
- `macbook`: aarch64-darwin laptop

## Flake inputs
- `nixpkgs`: nixos-unstable
- `home-manager`, `nix-darwin`: follow nixpkgs
- `nixos-wsl`: NixOS module for WSL2; follows nixpkgs
- `denix`: framework that auto-discovers hosts/modules/rices
- `spicetify-nix`, `zen-browser`, `nix-hazkey`: feature-specific inputs

## macOS conventions
- GUI apps: cross-platform tools via Nix, App Store / cask-first tools via Homebrew.
- Darwin common base: `modules/darwin-base.nix`
- macbook-specific UX tweaks: `modules/darwin-host-macbook.nix`
- Darwin local build target: `macbook-rift` by default, or the active rice-specific target when switching.
- Raycast is installed via Homebrew cask; Script Commands are deployed to `~/.config/raycast/scripts`.

## Validation (explicit request only)
- Lightweight (all platforms, no build): `nix flake check --all-systems --no-build`
- Darwin local build: `nh darwin build . -H <active-rice-target>`
- Format check: `nix fmt -- flake.nix hosts modules rices packages --ci --excludes 'hosts/*/hardware-configuration.nix'`

## Documentation expectations
- README changes should describe the actual personal workflow used in this repo.
- Mention `denix` and `nh` explicitly when explaining structure or operational commands.
- Do not rewrite the repo as a generic public template unless the user asks for that.

## Commit message format (required)
- Use Semantic Commit Message format for every commit:
  - `<type>: <title>`
- `<type>` must be one of: `chore`, `docs`, `feat`, `fix`, `refactor`, `style`, `test`.
- Do not include emoji in commit subjects or bodies.
- `<title>` must be imperative present tense and concise.
- Issue number is optional and not required here.
- Merge/Revert commits may keep default messages.
