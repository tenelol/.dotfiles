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

[`modules/pi-coding-agent`](./modules/pi-coding-agent) uses denix and Home Manager's `home.file` declarations for Pi configuration and resource links. `settings.json`, `models.json`, `keybindings.json`, and `zentui.json` are maintained in dotfiles and applied with the normal `nh` workflow; Pi's own settings saves are not persisted. The settings include the installed Pi changelog version so a fresh session does not try to write this marker to its read-only configuration; review it when upgrading Pi.

Pi has its own curated catalog under `~/.pi/agent/skills/`. [`skill-catalog.json`](./modules/pi-coding-agent/files/skill-catalog.json) selects shared directories with their references and extension-owned skills, including the Proxmox API/SSH helpers; [`files/skills/`](./modules/pi-coding-agent/files/skills) contains the small Pi-specific adaptations. `/skill:grill-me` expands the interview directly, and the diagnosis skill sends interactive human steps to a separate terminal. Shared originals and Codex discovery stay unchanged. Pi's global settings exclude automatic loading from `~/.agents/skills/`.

The dotfiles-only skill exclusion lives in `modules/pi-coding-agent/files/dotfiles-project-settings.json`. Home Manager exposes it at the Git-ignored `.pi/settings.json` entrypoint so this repository's `.agents/skills/` does not bypass the curated catalog. Other trusted projects keep their own normal project skill discovery, and explicit `--skill` paths remain available.

Ctrl+C interrupts work, and Ctrl+D exits when the editor is empty. Tool results show four-line previews with expandable details; the working line shows the active tool, elapsed time, thinking time, and tokens, followed by a compact turn summary. Outside Herdr, the notification hook sends a Ghostty notification after an interactive run fully settles. Inside Herdr, Herdr owns background completion/input notifications. The `browser` subagent receives the existing Playwright tool explicitly for scoped UI verification.

Pi's native subagent watchdog reviews the parent's repository changes at completion using `gpt-6-sol` / `xhigh`, with a two-minute deadline. Per-tool cadence and child watchdogs are disabled. The delegation reference requires task-specific `gate` or `acceptance.verify` commands for implementation work; the native runtime executes them and records acceptance separately from the child's success claims. Commands follow the target repository's validation permissions; there is no global guessed test command. `node modules/pi-coding-agent/tests/quality-gates.test.mjs` verifies the review trigger and passing/failing host checks.

Herdr uses Homebrew on macOS. Linux uses the official `herdr-bin` input (`herdrdev/herdr-nix`), which downloads hash-verified release binaries without compiling Rust or Zig. The `herdr` source input supplies the official Pi state hook and skill; the Linux package declaration checks that its release version matches the binary. Update the source pin with the installed Herdr release when upgrading. Home Manager links the upstream files directly; do not also run `herdr integration install pi` against these managed links. The local `herdr-ui` hook forwards Pi's blocking question events to the official hook. [`modules/herdr/files/config.toml`](./modules/herdr/files/config.toml) exposes agent state in the sidebar and enables terminal notifications. After applying an update with `nh`, check `herdr status`: the running server may still be the previous version. Restarting that server can stop its pane processes and remains a separate operation.

For macOS computer use, Homebrew declares the official `openclaw/tap/peekaboo` CLI; automatic Homebrew updates and upgrades remain disabled. Pi's `computer_use` tool wraps that CLI without an additional MCP server or Peekaboo AI-provider setup. It returns images inline, pins actions to a session's one-use observation, and distinguishes confirmed changes from unverified dispatch. Local execution (`--no-remote`) and snapshot argument handling are internal to the tool; the accompanying skill describes the observe/action/verify workflow. First use requires the appropriate Screen Recording/Accessibility permissions. The [source review](./modules/pi-coding-agent/research/computer-use-options.md) records runtime evidence and the opt-in GUI smoke test.

Local AI tools live in `files/tools/`, and the dashboard hook, artwork, and theme live together in `files/hooks/dashboard/`. Combined third-party extensions stay under `files/extensions/`. Their standard `~/.pi/agent/extensions/<name>` entrypoints link to editable local sources through `mkOutOfStoreSymlink`; required `node_modules` remain local and Git-ignored. Prompt templates remain with their owning extension and are linked into `~/.pi/agent/prompts`; reference documents are loaded only when instructions request them. Credentials, trust decisions, sessions, missions, caches, and generated model catalogs remain local under `~/.pi/agent`.

## Rice

### mac

| Rice | Window management |
| --- | --- |
| `mac` | Native macOS |
| `rift` | Rift |
| `aerospace` | AeroSpace + AutoRaise |

macOS wallpapers are managed in System Settings. denix/Home Manager does not set them during `nh darwin switch`.

### Linux

| Rice | Window management | Appearance |
| --- | --- | --- |
| `niri` | Niri | wallpaper |
| `hyprland` | Hyprland | wallpaper |
