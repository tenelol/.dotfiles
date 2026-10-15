
# Claude Code environment

## Nix and dotfiles

- This is an aarch64-darwin macOS environment managed by nix-darwin, denix and integrated Home Manager in `~/.dotfiles`.
- Read `~/.dotfiles/AGENTS.md` before changing system configuration. Prefer `nh`; use `dotfiles doctor --no-eval` to resolve the active rice-specific target before a requested build or switch.
- Use flake-based Nix, `nix develop` or `nix shell` for temporary tools. Manage persistent packages through dotfiles; follow its README for macOS apps.
- Format Nix with the repository's formatter and follow the surrounding nixpkgs style. Use `lib` helpers where available.

## Shell and editor

- The interactive shell is Fish. Keep interactive snippets Fish-compatible; use `#!/usr/bin/env bash` with `set -euo pipefail` for portable scripts.
- Fish configuration is managed through Home Manager; edit its source in dotfiles.
- The primary editor is Neovim, configured under `~/.dotfiles/modules/nvim/`. Use another editor workflow when the user requests it.

## Coding conventions

- Prefer simple, direct solutions and the surrounding code's style. Add abstractions only for existing multiple call sites.
- Comment non-obvious reasons and keep error handling for real failure cases.
- Unless a repository overrides it, use Semantic Commit Messages: `<type>: <title>`, with an imperative, concise title and type `chore`, `docs`, `feat`, `fix`, `refactor`, `style` or `test`.
