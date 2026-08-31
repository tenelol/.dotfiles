# dotfiles

個人環境向けの`denix`ベースdotfilesです。1つのflakeからNixOSと`nix-darwin`を管理し、Home Managerは各system configurationへ統合しています。操作には`nh`を使います。

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

`hosts/`、`modules/`、`rices/`内のNixファイルはdenixが再帰的に自動で読みます。Home Manager設定も各denix moduleの`home.*`に記述し、アプリ固有の非Nixファイルは所有moduleの`files/`に併置します。明示的にimportするpackage/runtime生成は`packages/`、rice用画像は`rices/wallpapers/`、機能固有テストは所有元の`tests/`へ置きます。

`.codex/skills/`はユーザー作成スキルの正本です。`codex-skills` moduleが`~/.codex/skills/`へ配備し、Codex管理の`.system`やplugin/runtimeスキルは対象にしません。

## Workflow

コミットメッセージは絵文字を含めず、`<type>: <title>`形式に統一します。GitHub ActionsのFlake Checkは`workflow_dispatch`による手動実行だけです。通常の変更では対象artifactのテスト・構文確認・diff確認を行い、Nix評価、host build、switchは明示的に依頼した場合だけ実行します。

## Commands

### Diagnose

```sh
dotfiles doctor
dotfiles doctor --no-eval
```

### Validate when explicitly requested

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

`macbook-rift`、`macbook-aerospace`、`macbook-mac`のいずれかを明示して切り替えます。build後のswitchも明示的に指定した場合だけ実行します。
