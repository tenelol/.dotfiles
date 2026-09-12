---
name: dotfiles-workflow
description: "この個人用denix dotfilesの構造変更・検証・nhによるbuildやswitchを扱うときに使う。"
---

# Dotfiles Workflow

## Start from current evidence

1. Read `AGENTS.md`, `git status --short`, and only the source files relevant to the request.
2. Treat the current repository, flake outputs, CI, and runtime state as authoritative when notes or docs disagree.
3. Identify the affected hosts and the cheapest sufficient validation before editing.
4. Preserve unrelated user changes.

## Keep the denix structure

Use the repository's AGENTS.md for structure and ownership boundaries; do not duplicate that inventory here. Keep host definitions thin, behavior in denix modules, integrated Home Manager under `home.*`, and non-Nix assets beside their owning feature. Preserve user-authored skills in `.agents/skills/` and leave runtime/plugin skills with their owner.

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
2. Commit a verified, single-responsibility small change unless the user asks not to. For large, multi-responsibility, or history-rewriting changes, leave the scoped diff ready and wait for explicit commit permission.
3. Report artifact checks, flake validation, host build/switch results, the Darwin target when applicable, and any pre-existing dirty paths.
