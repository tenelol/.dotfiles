---
name: dotfiles-workflow
description: Use when working in /home/tener/.dotfiles. Covers the denix host/module layout, the preferred nh-based validation/build workflow, and the documentation conventions for this personal multi-host NixOS and nix-darwin repo.
---

# Dotfiles Workflow

Use this skill for any repo change that touches `flake.nix`, `hosts/`, `modules/`, `home/`, `config/`, or repo docs.

## Quick map

- `flake.nix`: builds public outputs and passes shared `profile` / `inputs`
- `hosts/<name>/default.nix`: host metadata plus hardware import only
- `modules/*.nix`: denix-discovered shared or host-specific modules
- `home/home.nix`: shared Home Manager payload
- `legacy/`: archived old config, not part of the active flake

## Workflow

1. Read `flake.nix` and the relevant host/module files before editing.
2. Keep host files thin. Put reusable behavior in `modules/`.
3. If you add a new host or module file, make sure it is tracked by Git so denix can discover it from the flake source.
4. When changing docs, describe the repo as personal and nh-based, not as a generic starter template.

## Validation

- Default validation command: `nix flake check --all-systems --no-build`
- Linux hosts:
  - `nh os build . -H nixos`
  - `nh os build . -H nvidia-desktop`
  - `nh os build . -H nixos-server`
- Darwin host:
  - `nh darwin build . -H macbook`

Prefer `nh` over raw `nixos-rebuild` or `darwin-rebuild` unless the user explicitly asks otherwise.

## Repo facts to preserve

- Host inventory:
  - `nixos`: x86_64-linux laptop
  - `nvidia-desktop`: x86_64-linux desktop
  - `nixos-server`: x86_64-linux server
  - `macbook`: aarch64-darwin laptop
- Home Manager is integrated into system configurations; this flake does not expose standalone `homeConfigurations`.
- README should mention both `denix` and `nh` when explaining structure or operations.
