<INSTRUCTIONS>
## Repository context
- This directory is a personal `denix`-based dotfiles repository.
- It manages NixOS and `nix-darwin` hosts from one flake.
- Home Manager is integrated into the system configurations, not exposed as standalone `homeConfigurations`.
- This repo is optimized for the owner's machines and workflow, not as a generic starter template.

## Repository workflow
- Do not run CI-style Nix validation, host builds, or switches unless the user explicitly requests them. This includes `nix fmt -- ... --ci`, `nix flake check`, and `nh ... build|switch`. Direct artifact tests, syntax checks, and diff checks remain allowed.
- GitHub Actions Flake Check is manual-only through `workflow_dispatch`; do not add automatic push or pull-request triggers unless explicitly requested.
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
- When explicitly requested validation is confined to macOS/Darwin, skip Linux host builds; run the all-system no-build evaluation and only the confirmed Darwin target build.
- For docs, skills, tests, hooks, shell/Python assets, and static Home Manager file wiring, skip all-system Nix evaluation and host build/switch; run direct artifact tests instead.
- Preferred switch commands mirror the build commands with `switch` instead of `build`.
- For rebuild/switch on rice-enabled hosts, preserve the active rice by targeting the rice-specific configuration. On `macbook`, infer the active rice from the current desktop state, such as the AeroSpace process/config or active wallpaper, and prefer names such as `macbook-rift` or `macbook-aerospace` instead of bare `macbook`.
- Before running any rebuild/switch command, check that another `nh ... build`, `nh ... switch`, `darwin-rebuild`, or `nixos-rebuild` process is not already running. If one is active, do not start a conflicting activation.
- Never follow a build with a switch unless the user explicitly requested the switch.
- After a verified, single-responsibility small change, create a commit unless the user asks not to. For large, multi-responsibility, or history-rewriting changes, wait for explicit commit permission.

## denix structure
- `hosts/<name>/default.nix` should stay thin: host metadata plus hardware imports.
- Shared and host-specific behavior belongs in `modules/`.
- Express integrated Home Manager behavior through each denix module's `home.*` sections; do not add a separate shared `home/` module tree.
- Colocate deployed non-Nix sources under the owning `modules/<feature>/files/` directory. Rice wallpapers live in `rices/wallpapers/`, and package-owned sources belong beside their definition in `packages/`.
- Colocate artifact tests under the owning feature's `tests/` directory. Reserve `.codex/tests/` for Codex configuration and skill tests.
- `denix` recursively auto-discovers `.nix` files in `hosts/`, `modules/`, and `rices/`, so every `.nix` file there must be a denix module or an explicitly excluded generated hardware module.
- Do not manually import local denix modules. Keep `imports` for external Nix modules, generated hardware modules, and deliberate reusable-module boundaries.
- Keep single-consumer feature behavior in its owning denix module. Put explicitly imported package and runtime value generation in `packages/`; `modules/` remains reserved for valid denix modules.

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

## Codex skills
- Keep user-authored Codex skills under `.codex/skills/` as the Git-managed source of truth. The `codex-skills` module deploys each skill into `~/.codex/skills/` without managing Codex-owned `.system` or runtime/plugin skills.
- `dotfiles-workflow`: use when changing this repo's Nix structure, docs, or validation workflow.
- `windows-via-crd`: use only when operating the personal Windows PC `Tener` through Chrome Remote Desktop.

## Commit message format (required)
- Use Semantic Commit Message format for every commit:
  - `<type>: <title>`
- `<type>` must be one of: `chore`, `docs`, `feat`, `fix`, `refactor`, `style`, `test`.
- Do not include emoji in commit subjects or bodies.
- `<title>` must be imperative present tense and concise.
- Issue number is optional and not required here.
- Merge/Revert commits may keep default messages.
</INSTRUCTIONS>
