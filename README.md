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

- [flake.nix](./flake.nix): flake entrypoint。`denix.lib.configurations` で host/module を束ねる
- [hosts](./hosts): host 名、種別、system、rice や boot のような host 固有 metadata と hardware import だけを置く薄い定義
- [modules](./modules): denix が自動発見する shared / host-specific module
- [rices](./rices): denix の rice 定義。今は共通 wallpaper を切り替える最小実装
- [home/home.nix](./home/home.nix): 共通 Home Manager 設定
- [config](./config): Neovim、fish、niri、waybar などの実ファイル
- [packages](./packages): 軽い独自 package 定義
- [legacy](./legacy): 退避した旧構成。現行 flake では未使用

`hosts/` と `modules/` と `rices/` は `denix` が自動で読むので、新しい `.nix` を足したら Git 管理下に置く前提です。
NixOS host の `hosts/*/hardware-configuration.nix` は `flake.nix` 側で自動除外しているので、host 追加時に除外リストを手で更新する必要はありません。
Darwin の共通土台は [modules/darwin-base.nix](./modules/darwin-base.nix)、`macbook` 固有の UX 調整は [modules/darwin-host-macbook.nix](./modules/darwin-host-macbook.nix) に寄せています。
macOS の GUI アプリは「cross-platform なものは Nix、App Store / cask-first なものは Homebrew」を目安に分けています。

## Codex

`macbook` では Homebrew cask で `codex-app` に加えて `codex` CLI も入れる運用です。
`nh darwin switch . -H macbook` 後は terminal から `codex` をそのまま叩けます。

初回ログインだけは別途必要です。ブラウザ認証を使うなら:

```sh
codex login
```

`OPENAI_API_KEY` を使うなら、普段どおり `~/.config/fish/secrets.fish` などで環境変数を読み込んだうえで:

```sh
printenv OPENAI_API_KEY | codex login --with-api-key
```

## Raycast

`macbook` では Raycast を Homebrew cask で入れています。Window Management は Raycast 側で hotkey を割り当て、Script Commands はこの repo から配る前提です。

Script Commands は `~/.config/raycast/scripts` に展開されるので、Raycast の `Extensions` → `Script Commands` でその directory を追加すると使えます。

最初に入れてある個人用コマンド:

- `Dotfiles: Rebuild macbook`: Terminal.app を開いて `nh darwin switch . -H macbook` を実行

Raycast の Script Command 自体は対話的な `sudo` に弱いので、リビルドは Raycast 内で直接完結させず、Terminal.app を開いてそこで `nh darwin switch` を走らせる形にしています。

## Workflow

軽量評価:

```sh
./scripts/validate eval
```

Darwin 実機がまだ無い段階でも `macbook` host を腐らせないため、普段の軽量チェックは Linux / Darwin をまとめて見る `./scripts/validate eval` を基準にします。
このコマンドは各 configuration の `system.build.toplevel.drvPath` を直接評価して、全 host と rice 派生 config が壊れていないかを build なしで確認します。
CI ではまず `./scripts/validate eval` で全 platform の評価を見て、その上で `checks.x86_64-linux.build-*` を個別に build します。ローカルの実運用は引き続き `nh os build` / `nh darwin build` を使います。Darwin は GitHub Actions の Linux runner では build せず、ローカルで `./scripts/validate darwin` を回す運用です。

整形確認:

```sh
nix fmt -- flake.nix hosts modules rices home packages --ci --excludes 'hosts/*/hardware-configuration.nix' --excludes 'legacy/**'
```

Linux host を build:

```sh
./scripts/validate linux
```

Linux host を switch:

```sh
nh os switch . -H nixos
nh os switch . -H nvidia-desktop
nh os switch . -H nixos-server
```

macOS host を build / switch:

```sh
./scripts/validate darwin
nh darwin build . -H macbook
nh darwin switch . -H macbook
```

macOS に初回導入するときは、まず upstream Nix を入れてからこの repo を初回 switch します。
この repo は `nix-darwin` 側で `nix.*` を管理しているので、Determinate installer を使う場合も upstream Nix を選ぶ前提です。

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --prefer-upstream-nix
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
cd ~/.dotfiles
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
sudo nix run github:nix-darwin/nix-darwin#darwin-rebuild -- switch --flake .#macbook
```

初回は Homebrew を公式インストーラで入れてから `switch` します。以降の cask 管理は既存の `homebrew.*` 設定に寄せています。
その後は `nh` と `darwin-rebuild` が入るので、通常どおり `nh darwin build . -H macbook` / `nh darwin switch . -H macbook` を使います。

rice を切り替えて build:

```sh
nh os build . -H nvidia-desktop-redmoon
nh darwin build . -H macbook-redmoon
```

`nh` を使う前提で書いています。`nixos-rebuild` や `darwin-rebuild` を直接叩くより、普段の運用では `nh` を優先します。
共通の評価入口として `./scripts/validate` を置いていて、`eval` / `linux` / `darwin` の 3 モードを使い分けます。
通常の `nixos` / `nvidia-desktop` / `macbook` は `indigo` rice を使い、`*-redmoon` のような派生 config で別 wallpaper を試せます。Linux desktop では `switch` 後に Home Manager activation が `apply-theme-wallpaper` を叩くので、`niri` 上でも wallpaper が即時反映されます。headless な `nixos-server` にも rice 名は付きますが、今のところ見た目には影響しません。

## Design Notes

- 共通プロフィール値は [flake.nix](./flake.nix) の `profile` に集約
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
