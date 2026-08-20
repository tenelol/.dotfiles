# tener dotfiles

個人用の `denix` ベース multi-host dotfiles。NixOS と `nix-darwin` を1つのflakeで管理し、Home Managerは各systemに統合しています。

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
| [`modules`](./modules) | denix-discovered system and Home Manager modules |
| [`home`](./home) | shared Home Manager payload |
| [`config`](./config) | application configuration files |
| [`rices`](./rices) | theme and desktop variants |
| [`lib`](./lib) | explicitly imported helpers |

`hosts/`、`modules/`、`rices/` はdenixが自動で読みます。新しいNixファイルはGit管理下に置きます。

## Commands

### Diagnose

```sh
dotfiles doctor
dotfiles doctor --no-eval
```

### Check

```sh
nix flake check --all-systems --no-build
```

### Linux

```sh
nh os build . -H surface
nh os switch . -H surface

nh os build . -H nvidia-desktop
nh os switch . -H nvidia-desktop
```

### macOS

```sh
nh darwin build . -H macbook-rift
nh darwin switch . -H macbook-rift
```

`macbook-rift`、`macbook-aerospace`、`macbook-mac` のいずれかを明示して切り替えます。
