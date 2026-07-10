---
name: dotfiles-workflow
description: Edit, review, validate, build, switch, or document the personal denix-based NixOS and nix-darwin repository at /Users/tener/.dotfiles or /home/tener/.dotfiles. Use for work on flake.nix, hosts, modules, rices, Home Manager, config, packages, lib, scripts, repository docs, validation, or host activation. Covers nh-based operations and rice-safe Darwin target selection.
---

# Dotfiles Workflow

## Start from current evidence

1. Read `AGENTS.md`, `git status --short`, and only the source files relevant to the request.
2. Treat the current repository, flake outputs, CI, and runtime state as authoritative when notes or docs disagree.
3. Identify the affected hosts and the cheapest sufficient validation before editing.
4. Preserve unrelated user changes. Ignore `legacy/` unless the user explicitly requests comparison or revival.

## Keep the denix structure

- Keep `hosts/<name>/default.nix` thin: host metadata plus hardware imports.
- Put denix-discovered behavior in `modules/`, including nested module files, and rice variants in `rices/`.
- Keep the shared Home Manager payload in `home/`. Do not add standalone `homeConfigurations` without an explicit architecture change.
- Put explicitly imported helpers and generated-data builders in `lib/`, package definitions in `packages/`, and deployed source files in `config/`.
- Treat `flake.nix` as the source of truth for platform-filtered `nixosConfigurations`, `darwinConfigurations`, `checks`, and `formatter` outputs.
- Add every new flake-referenced file to Git before evaluation; flakes omit untracked files.
- Keep active Nix files at or below the repository's 500-line structure limit.
- Describe this repository as personal, `denix`-based, and `nh`-operated; do not recast it as a generic starter template.

## Validate with the narrowest useful work

1. Run the fastest artifact-specific check first. For active Nix changes, run `nix fmt -- flake.nix hosts modules rices home packages lib --ci --excludes 'hosts/*/hardware-configuration.nix' --excludes 'legacy/**'`; use `./scripts/validate structure` as a cheap preflight when useful.
2. Run `nix flake check --all-systems --no-build` before any host build and before finalizing the change. For active Nix changes, `./scripts/validate eval` runs the structure check plus that same flake check; use it instead of repeating both commands.
3. Build only configurations whose closure can change:
   - Use `nh os build . -H <host>` for an affected Linux host.
   - Use `./scripts/validate linux` only when all Linux hosts need building.
   - Use `nh darwin build . -H <confirmed-target>` for Darwin.
   - For a macOS/Darwin-only change, skip every Linux host build and `./scripts/validate linux`; keep the all-system no-build evaluation, then build only the confirmed Darwin target.
4. Skip host builds for docs- or skill-only changes.

Always pass an explicit mode to `./scripts/validate`; its bare invocation defaults to all Linux builds. Prefer `nh` over raw `nixos-rebuild` or `darwin-rebuild` unless the user explicitly requests otherwise.

## Build and activate safely

1. Before every build or switch, verify that no `nh`, `darwin-rebuild`, or `nixos-rebuild` build/switch is already running. Do not start a conflicting operation.
2. After a successful host build, run the matching switch in the same turn unless the user asked to avoid activation.
3. Reuse the exact Linux host or confirmed Darwin target between build and switch.

For Darwin:

1. Never use bare `macbook`. Resolve one of `macbook-rift`, `macbook-aerospace`, or `macbook-mac`.
2. Run `dotfiles doctor --no-eval` or `dotfiles-doctor --no-eval` and use its `switch target` as canonical. This command also reports conflicting rebuild processes.
3. If the doctor command is unavailable or cannot determine the target, inspect the AeroSpace/Rift process state and `~/.config/theme/wallpaper.png`; use `macbook-rift` only as the final fallback.
4. Do not use `./scripts/validate darwin` as an active-rice selector; it currently builds `macbook-rift` unconditionally.
5. For a build followed by switch, re-run the doctor command immediately before switching. Switch only the confirmed target; if it differs from the built target, build the newly confirmed target first.

## Finish the change

1. Review the final diff and status; keep unrelated paths out of the commit.
2. Use `$dotfiles-commit` and commit the completed scoped change unless the user asked not to commit.
3. Report artifact checks, flake validation, host build/switch results, the Darwin target when applicable, and any pre-existing dirty paths.
