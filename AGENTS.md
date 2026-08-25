<INSTRUCTIONS>
## Repository context
- This directory is a personal `denix`-based dotfiles repository.
- It manages NixOS and `nix-darwin` hosts from one flake.
- Home Manager is integrated into the system configurations, not exposed as standalone `homeConfigurations`.
- This repo is optimized for the owner's machines and workflow, not as a generic starter template.

## Repository workflow
- Prefer `nh` commands over raw `nixos-rebuild` / `darwin-rebuild` unless the user explicitly asks otherwise.
- Preferred validation command: `nix flake check --all-systems --no-build`
- Preferred Linux build commands:
  - `nh os build . -H adguard-home`
  - `nh os build . -H surface`
  - `nh os build . -H nvidia-desktop`
  - `nh os build . -H web-server`
  - `nh os build . -H nas`
  - `nh os build . -H wsl`
- Preferred Darwin build command:
  - `nh darwin build . -H macbook-rift`
- When a change is confined to macOS/Darwin, skip Linux host builds and `./scripts/validate linux`; run the all-system no-build evaluation and only the confirmed Darwin target build.
- Preferred switch commands mirror the build commands with `switch` instead of `build`.
- For rebuild/switch on rice-enabled hosts, preserve the active rice by targeting the rice-specific configuration. On `macbook`, infer the active rice from the current desktop state, such as the AeroSpace process/config or active wallpaper, and prefer names such as `macbook-rift` or `macbook-aerospace` instead of bare `macbook`.
- Before running any rebuild/switch command, check that another `nh ... build`, `nh ... switch`, `darwin-rebuild`, or `nixos-rebuild` process is not already running. If one is active, do not start a conflicting activation.
- If a host-specific `nh ... build` succeeds and the user has not asked to avoid activation, follow it with the matching `nh ... switch` in the same turn.
- After completing a requested fix or change, create a commit in the same turn unless the user asks not to commit.

## denix structure
- `hosts/<name>/default.nix` should stay thin: host metadata plus hardware imports.
- Shared and host-specific behavior belongs in `modules/`.
- Express integrated Home Manager behavior through each denix module's `home.*` sections; do not add a separate shared `home/` module tree.
- Colocate deployed non-Nix sources under the owning `modules/<feature>/files/` directory. Package-owned sources belong beside their definition in `packages/`.
- `denix` recursively auto-discovers `.nix` files in `hosts/`, `modules/`, and `rices/`, so every `.nix` file there must be a denix module or an explicitly excluded generated hardware module.
- Do not manually import local denix modules. Keep `imports` for external Nix modules, generated hardware modules, and deliberate reusable-module boundaries.
- `lib/` is for explicitly imported helpers and generated-data builders; keep bloat-prone implementation details there instead of growing auto-discovered modules.
- `legacy/` is not part of the active flake unless the user explicitly asks to revive or compare it.

## Host inventory
- `adguard-home`: x86_64-linux Proxmox guest config; VM stays stopped until router/DHCP integration is safe
- `surface`: x86_64-linux laptop
- `nvidia-desktop`: x86_64-linux desktop
- `web-server`: x86_64-linux Proxmox guest for personal sites
- `nas`: x86_64-linux Proxmox guest configuration; deployment waits for the data HDD
- `wsl`: x86_64-linux NixOS-WSL environment
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
