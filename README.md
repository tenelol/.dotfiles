# tener dotfiles

個人用の `denix` ベース multi-host dotfiles です。  
NixOS と `nix-darwin` を 1 つの flake で管理し、Home Manager は各 system に統合しています。

汎用テンプレートではなく、自分のホストと普段使う GUI/CLI、Neovim、Niri 周りに最適化した repo です。

## Host

- `nixos`: x86_64 Linux laptop
- `nvidia-desktop`: x86_64 Linux desktop
- `nixos-server`: x86_64 Linux server
- `macbook`: aarch64 Darwin laptop

## Architecture

- [flake.nix](/home/tener/.dotfiles/flake.nix): flake entrypoint。`denix.lib.configurations` で host/module を束ねる
- [hosts](/home/tener/.dotfiles/hosts): host 名、種別、system、hardware import だけを置く薄い定義
- [modules](/home/tener/.dotfiles/modules): denix が自動発見する shared / host-specific module
- [home/home.nix](/home/tener/.dotfiles/home/home.nix): 共通 Home Manager 設定
- [config](/home/tener/.dotfiles/config): Neovim、fish、niri、waybar などの実ファイル
- [packages](/home/tener/.dotfiles/packages): 軽い独自 package 定義
- [legacy](/home/tener/.dotfiles/legacy): 退避した旧構成。現行 flake では未使用

`hosts/` と `modules/` は `denix` が自動で読むので、新しい `.nix` を足したら Git 管理下に置く前提です。

## Workflow

評価:

```sh
nix flake check --no-build
```

Linux host を build:

```sh
nh os build . -H nixos
nh os build . -H nvidia-desktop
nh os build . -H nixos-server
```

Linux host を switch:

```sh
nh os switch . -H nixos
nh os switch . -H nvidia-desktop
nh os switch . -H nixos-server
```

macOS host を build / switch:

```sh
nh darwin build . -H macbook
nh darwin switch . -H macbook
```

`nh` を使う前提で書いています。`nixos-rebuild` や `darwin-rebuild` を直接叩くより、普段の運用では `nh` を優先します。

## Design Notes

- 共通プロフィール値は [flake.nix](/home/tener/.dotfiles/flake.nix) の `profile` に集約
- Home Manager は standalone `homeConfigurations` ではなく system 側に統合
- Linux desktop は `niri` 前提
- macOS でも同じ Neovim 設定を使う。clipboard や language toolchain は Nix 側で揃える
- VS Code の vendor 拡張は [vendor/vscode-extensions](/home/tener/.dotfiles/vendor/vscode-extensions) に展開して declarative に読む

## Editing Notes

- repo の説明を書くときは「個人用」「denix で host/module を自動発見」「`nh` で build/switch」を前提にする
- 新しい host を追加するときは `hosts/<name>/default.nix` を作り、必要なら hardware config を同階層に置く
- 新しい module は `modules/` に置けば denix が拾う
