<INSTRUCTIONS>
## Repository context
- This directory is a personal `denix`-based dotfiles repository.
- It manages NixOS and `nix-darwin` hosts from one flake.
- Home Manager is integrated into the system configurations, not exposed as standalone `homeConfigurations`.
- This repo is optimized for the owner's machines and workflow, not as a generic starter template.

## Repository workflow
- Prefer `nh` commands over raw `nixos-rebuild` / `darwin-rebuild` unless the user explicitly asks otherwise.
- Preferred validation command: `nix flake check --no-build`
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
- `denix` auto-discovers `hosts/` and `modules/`, so new `.nix` files should be committed to Git if they are meant to participate in flake evaluation.
- `legacy/` is not part of the active flake unless the user explicitly asks to revive or compare it.

## Host inventory
- `nixos`: x86_64-linux laptop
- `nvidia-desktop`: x86_64-linux desktop
- `nixos-server`: x86_64-linux server
- `macbook`: aarch64-darwin laptop

## Documentation expectations
- README changes should describe the actual personal workflow used in this repo.
- Mention `denix` and `nh` explicitly when explaining structure or operational commands.
- Do not rewrite the repo as a generic public template unless the user asks for that.

## Repo-local skills
- `dotfiles-workflow`: use when changing this repo's Nix structure, docs, or validation workflow.
- `dotfiles-commit`: use when preparing a commit or choosing a commit message for this repo.

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
</INSTRUCTIONS>
