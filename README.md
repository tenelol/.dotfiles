# dotfiles

## Stack

- NixOS / nix-darwin / Home Manager
- denix / nh / nixvim
- sops-nix / Tailscale / systemd-resolved
- nixbuild.net remote builders
- GitHub Actions / Determinate Nix / Magic Nix Cache
- Neovim / Fish / Ghostty
- Niri（Linux）/ Rift・AeroSpace（macOS）

## Hosts

| Host | Platform | Role |
| --- | --- | --- |
| `surface` | x86_64 Linux | laptop |
| `nvidia-desktop` | x86_64 Linux | desktop |
| `macbook` | aarch64 Darwin | laptop |
| `web-server` | x86_64 Linux | personal sites |
| `adguard-home` | x86_64 Linux | DNS filter VM config |
| `nas` | x86_64 Linux | storage VM config |
| `wsl` | x86_64 Linux | NixOS-WSL |

## Layout

| Path | Purpose |
| --- | --- |
| [`flake.nix`](./flake.nix) | inputs and configuration outputs |
| [`hosts`](./hosts) | host identity, platform, hardware imports |
| [`modules`](./modules) | denix-discovered system/Home Manager modules and their colocated `files/` assets |
| [`rices`](./rices) | theme and desktop variants, including wallpapers |
| [`packages`](./packages) | custom packages, runtime builders, package-owned sources, and their tests |
| [`.codex/skills`](./.codex/skills) | Git-managed user-authored Codex skills |
| [`secrets`](./secrets) | sops-nix encrypted secrets |

## Rice

| Rice | Window management | Appearance |
| --- | --- | --- |
| `rift` | Rift | Rift wallpaper and Ghostty theme |
| `aerospace` | AeroSpace + AutoRaise | AeroSpace wallpaper and Ghostty / SketchyBar / JankyBorders theme |
