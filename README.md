# tener dotfiles

個人用の `denix` ベース multi-host dotfiles です。  
NixOS と `nix-darwin` を 1 つの flake で管理し、Home Manager は各 system に統合しています。

汎用テンプレートではなく、自分のホストと普段使う GUI/CLI、Neovim、Niri 周りに最適化した repo です。

## Host

- `nixos`: x86_64 Linux laptop
- `nvidia-desktop`: x86_64 Linux desktop
- `nixos-server`: x86_64 Linux headless server
- `macbook`: aarch64 Darwin laptop

## Architecture

- [flake.nix](/home/tener/.dotfiles/flake.nix): flake entrypoint。`denix.lib.configurations` で host/module を束ねる
- [hosts](/home/tener/.dotfiles/hosts): host 名、種別、system、rice や boot のような host 固有 metadata と hardware import だけを置く薄い定義
- [modules](/home/tener/.dotfiles/modules): denix が自動発見する shared / host-specific module
- [rices](/home/tener/.dotfiles/rices): denix の rice 定義。今は共通 wallpaper を切り替える最小実装
- [home/home.nix](/home/tener/.dotfiles/home/home.nix): 共通 Home Manager 設定
- [config](/home/tener/.dotfiles/config): Neovim、fish、niri、waybar などの実ファイル
- [packages](/home/tener/.dotfiles/packages): 軽い独自 package 定義
- [legacy](/home/tener/.dotfiles/legacy): 退避した旧構成。現行 flake では未使用

`hosts/` と `modules/` と `rices/` は `denix` が自動で読むので、新しい `.nix` を足したら Git 管理下に置く前提です。
NixOS host の `hosts/*/hardware-configuration.nix` は `flake.nix` 側で自動除外しているので、host 追加時に除外リストを手で更新する必要はありません。

## Workflow

評価:

```sh
nix flake check --all-systems --no-build
```

Darwin 実機がまだ無い段階でも `macbook` host を腐らせないため、普段の評価は Linux / Darwin をまとめて見る `--all-systems` を基準にします。
`flake.nix` の `checks` には Linux host の `system.build.toplevel` も含めてあるので、`--no-build` を外した `nix flake check --all-systems` では Linux 側の実 build まで確認できます。
CI ではまず `nix flake check --all-systems --no-build` で全 platform の評価を見て、その上で `checks.x86_64-linux.build-*` を個別に build します。ローカルの実運用は引き続き `nh os build` / `nh darwin build` を使います。Darwin は GitHub Actions の Linux runner では build せず、ローカルで `nh darwin build . -H macbook` を回す運用です。

整形確認:

```sh
nix fmt -- flake.nix hosts modules rices home packages --ci --excludes 'hosts/*/hardware-configuration.nix' --excludes 'legacy/**'
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

rice を切り替えて build:

```sh
nh os build . -H nvidia-desktop-redmoon
nh darwin build . -H macbook-redmoon
```

`nh` を使う前提で書いています。`nixos-rebuild` や `darwin-rebuild` を直接叩くより、普段の運用では `nh` を優先します。
通常の `nixos` / `nvidia-desktop` / `macbook` は `indigo` rice を使い、`*-redmoon` のような派生 config で別 wallpaper を試せます。Linux desktop では `switch` 後に Home Manager activation が `apply-theme-wallpaper` を叩くので、`niri` 上でも wallpaper が即時反映されます。headless な `nixos-server` にも rice 名は付きますが、今のところ見た目には影響しません。

## Design Notes

- 共通プロフィール値は [flake.nix](/home/tener/.dotfiles/flake.nix) の `profile` に集約
- Home Manager は standalone `homeConfigurations` ではなく system 側に統合
- bootloader のような machine 固有前提は host metadata で明示し、共通 base module に埋め込まない
- 外部バイナリに依存する integration は explicit allowlist に寄せ、将来 host を足しても暗黙に広げない
- Linux desktop は `niri` 前提
- `nixos.base` は全 NixOS host 共通、desktop 前提は host 非 server の module に分離
- macOS でも同じ Neovim 設定を使う。clipboard や language toolchain は Nix 側で揃える

## Editing Notes

- repo の説明を書くときは「個人用」「denix で host/module を自動発見」「`nh` で build/switch」を前提にする
- 新しい host を追加するときは `hosts/<name>/default.nix` を作り、必要なら hardware config を同階層に置く
- 新しい module は `modules/` に置けば denix が拾う
