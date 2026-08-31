---
name: dotfiles-workflow
description: Edit, review, validate, build, switch, or document the personal denix-based NixOS and nix-darwin repository at /Users/tener/.dotfiles or /home/tener/.dotfiles. Use for work on flake.nix, hosts, modules, rices, Home Manager, config, packages, lib, scripts, repository docs, validation, or host activation. Covers nh-based operations and rice-safe Darwin target selection.
---

# Dotfiles Workflow

## Start from current evidence

1. Read `AGENTS.md`, `git status --short`, and only the source files relevant to the request.
2. Treat the current repository, flake outputs, CI, and runtime state as authoritative when notes or docs disagree.
3. Identify the affected hosts and the cheapest sufficient validation before editing.
4. Preserve unrelated user changes.

## Keep the denix structure

- Keep `hosts/<name>/default.nix` thin: host metadata plus hardware imports.
- Put denix-discovered behavior in `modules/`, including nested module files, and rice variants in `rices/`.
- Put integrated Home Manager behavior in each denix module's `home.*` sections. Do not create a separate shared `home/` module tree or standalone `homeConfigurations` without an explicit architecture change.
- Colocate deployed non-Nix sources under the owning `modules/<feature>/files/` directory, rice wallpapers in `rices/wallpapers/`, package-owned sources beside their definition in `packages/`, and user-authored Codex skills in `.codex/skills/`. Keep Codex-owned `.system` and runtime/plugin skills outside the repository.
- Put artifact tests beside their owner under a feature-local `tests/` directory; use `.codex/tests/` only for Codex configuration and skill tests.
- Do not manually import local denix modules. Keep imports for external modules, generated hardware modules, and deliberate reusable-module boundaries.
- Keep single-consumer behavior in its owning denix module. Put explicitly imported package and runtime value generation in `packages/`; do not create a top-level `lib/` solely as an escape hatch from denix auto-discovery.
- Treat `flake.nix` as the source of truth for platform-filtered `nixosConfigurations`, `darwinConfigurations`, `checks`, and `formatter` outputs.
- Add every new flake-referenced file to Git before evaluation; flakes omit untracked files.
- Keep active Nix files at or below the repository's 500-line structure limit.
- Describe this repository as personal, `denix`-based, and `nh`-operated; do not recast it as a generic starter template.

## Validate with the narrowest useful work

1. By default, run only the fastest artifact-specific tests, syntax checks, and diff checks.
2. Do not run CI-style Nix validation, host builds, or switches unless the user explicitly requests them. This includes `nix fmt -- ... --ci`, `nix flake check`, and `nh ... build|switch`.
3. When the user explicitly requests Nix validation, build only configurations whose closure can change:
   - Use `nh os build . -H <host>` for an affected Linux host.
   - Use `nh darwin build . -H <confirmed-target>` for Darwin.
   - For a macOS/Darwin-only change, skip every Linux host build; keep the all-system no-build evaluation, then build only the confirmed Darwin target.
4. Skip host builds for docs, skills, tests, hooks, shell/Python assets, and static Home Manager file wiring even when running direct checks.

Prefer `nh` over raw `nixos-rebuild` or `darwin-rebuild` unless the user explicitly requests otherwise.

## Build and activate safely

1. Before every build or switch, verify that no `nh`, `darwin-rebuild`, or `nixos-rebuild` build/switch is already running. Do not start a conflicting operation.
2. After a successful host build, run the matching switch only when the user explicitly requested the switch.
3. Reuse the exact Linux host or confirmed Darwin target between build and switch.

For Darwin:

1. Never use bare `macbook`. Resolve one of `macbook-rift`, `macbook-aerospace`, or `macbook-mac`.
2. Run `dotfiles doctor --no-eval` or `dotfiles-doctor --no-eval` and use its `switch target` as canonical. This command also reports conflicting rebuild processes.
3. If the doctor command is unavailable or cannot determine the target, inspect the AeroSpace/Rift process state and `~/.config/theme/wallpaper.png`; use `macbook-rift` only as the final fallback.
4. For a build followed by switch, re-run the doctor command immediately before switching. Switch only the confirmed target; if it differs from the built target, build the newly confirmed target first.

## Finish the change

1. Review the final diff and status; keep unrelated paths out of the commit.
2. Commit only when the user explicitly asks; otherwise leave the verified scoped diff ready for review.
3. Report artifact checks, flake validation, host build/switch results, the Darwin target when applicable, and any pre-existing dirty paths.
