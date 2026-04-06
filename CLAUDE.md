## Repository context
- This directory is a personal `denix`-based dotfiles repository.
- It manages NixOS and `nix-darwin` hosts from one flake.
- Home Manager is integrated into the system configurations, not exposed as standalone `homeConfigurations`.
- This repo is optimized for the owner's machines and workflow, not as a generic starter template.

## Repository workflow
- Prefer `nh` commands over raw `nixos-rebuild` / `darwin-rebuild` unless the user explicitly asks otherwise.
- Preferred validation command: `nix flake check --all-systems --no-build`
- Preferred Linux build commands:
  - `nh os build . -H nixos`
  - `nh os build . -H nvidia-desktop`
  - `nh os build . -H nixos-server`
- Preferred Darwin build command:
  - `nh darwin build . -H macbook`
- Preferred switch commands mirror the build commands with `switch` instead of `build`.

## denix structure
- `hosts/<name>/default.nix` should stay thin: host metadata plus hardware imports.
- Shared and host-specific behavior belongs in `modules/`.
- `denix` auto-discovers `hosts/`, `modules/`, and `rices/`, so new `.nix` files must be committed to Git to participate in flake evaluation.
- `legacy/` is not part of the active flake unless the user explicitly asks to revive or compare it.

## Directory layout
- `flake.nix`: flake entrypoint; uses `denix.lib.configurations` to wire hosts and modules.
- `hosts/`: thin per-host definitions (metadata + hardware import only).
- `modules/`: denix auto-discovered shared and host-specific modules.
- `rices/`: denix rice definitions (currently minimal — common wallpaper switching).
- `home/home.nix`: shared Home Manager configuration.
- `config/`: raw config files for Neovim, fish, niri, waybar, etc.
- `packages/`: lightweight custom package definitions.
- `legacy/`: retired configs; not used in the active flake.

## Host inventory
- `nixos`: x86_64-linux laptop
- `nvidia-desktop`: x86_64-linux desktop
- `nixos-server`: x86_64-linux headless server
- `macbook`: aarch64-darwin laptop

## Flake inputs
- `nixpkgs`: nixos-unstable
- `home-manager`, `nix-darwin`: follow nixpkgs
- `denix`: framework that auto-discovers hosts/modules/rices
- `spicetify-nix`, `zen-browser`, `nix-hazkey`: feature-specific inputs

## macOS conventions
- GUI apps: cross-platform tools via Nix, App Store / cask-first tools via Homebrew.
- Darwin common base: `modules/darwin-base.nix`
- macbook-specific UX tweaks: `modules/darwin-host-macbook.nix`
- Raycast is installed via Homebrew cask; Script Commands are deployed to `~/.config/raycast/scripts`.

## Validation scripts
- Lightweight (all platforms, no build): `./scripts/validate eval`
- Darwin local check: `./scripts/validate darwin`
- Format check: `nix fmt -- flake.nix hosts modules rices home packages --ci --excludes 'hosts/*/hardware-configuration.nix' --excludes 'legacy/**'`

## Documentation expectations
- README changes should describe the actual personal workflow used in this repo.
- Mention `denix` and `nh` explicitly when explaining structure or operational commands.
- Do not rewrite the repo as a generic public template unless the user asks for that.

## Commit message format (required)
- Use Semantic Commit Message format for every commit:
  - `<Type>: <Emoji> <Title>`
- `<Type>` must be one of: `chore`, `docs`, `feat`, `fix`, `refactor`, `style`, `test`
- `<Emoji>` is required. Recommended mapping:
  - `chore` -> 🧹
  - `docs` -> 📝
  - `feat` -> ✨
  - `fix` -> 🐛
  - `refactor` -> ♻️
  - `style` -> 💄
  - `test` -> ✅
- `<Title>` must be imperative present tense and concise.
- Issue number is optional and not required here.
- Merge/Revert commits may keep default messages.
