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
| [`modules`](./modules) | denix-discovered system/Home Manager modules; feature directories contain their Nix definitions (normally `default.nix`), `files/`, and `tests/` |
| [`rices`](./rices) | theme and desktop variants, including wallpapers |
| [`packages`](./packages) | custom packages, runtime builders, package-owned sources, and their tests |
| [`.agents/skills`](./.agents/skills) | Provider-original Codex skills and local integrations, deployed by Home Manager |
| [`secrets`](./secrets) | sops-nix encrypted secrets |

## Codex skills

Keep provider files unchanged when refreshing a skill. Local integrations are limited to `imoocs`, `proxmox-pve`, `line-delivery`, `project-context-init`, and the personal `subagent-model-router` policy. The existing denix module and Home Manager deployment remain unchanged.

| Skills | Provider |
| --- | --- |
| Tax and document-reading skills (24) | [kazukinagata/shinkoku](https://github.com/kazukinagata/shinkoku) |
| Engineering and productivity skills (25) | [mattpocock/skills](https://github.com/mattpocock/skills) |
| `frontend-design` | [anthropics/skills](https://github.com/anthropics/skills) |
| `find-skills` | [vercel-labs/skills](https://github.com/vercel-labs/skills) |

`hatch-pet` uses the v2 skill bundled in ChatGPT.app through `~/.agents/skills/hatch-pet`; it is not copied into this repository. Pi extension-owned skills are linked from their editable extension directories rather than duplicated. Skill security checks use the upstream [Cisco AI Defense scanner](https://github.com/cisco-ai-defense/skill-scanner) CLI (`skill-scanner`).

## Pi

[`modules/pi-coding-agent`](./modules/pi-coding-agent) uses denix and Home Manager's `home.file` declarations for Pi configuration and resource links. `settings.json` and `models.json` are maintained in dotfiles and applied with the normal `nh` workflow; Pi's own settings saves are not persisted. The settings include the installed Pi changelog version so a fresh session does not try to write this marker to its read-only configuration; review it when upgrading Pi.

Local AI tools live in `files/tools/`, and the dashboard hook, artwork, and theme live together in `files/hooks/dashboard/`. Combined third-party extensions stay under `files/extensions/`. Their standard `~/.pi/agent/extensions/<name>` entrypoints link to editable local sources through `mkOutOfStoreSymlink`; required `node_modules` remain local and Git-ignored. Prompt templates remain with their owning extension and are linked into `~/.pi/agent/prompts`; reference documents are loaded only when instructions request them. Credentials, trust decisions, sessions, missions, caches, and generated model catalogs remain local under `~/.pi/agent`.

## Rice

### mac

| Rice | Window management | Appearance |
| --- | --- | --- |
| `mac` | Native macOS | wallpaper|
| `rift` | Rift | wallpaper |
| `aerospace` | AeroSpace + AutoRaise | wallpaper |

### Linux

| Rice | Window management | Appearance |
| --- | --- | --- |
| `niri` | Niri | wallpaper |
| `hyprland` | Hyprland | wallpaper |
