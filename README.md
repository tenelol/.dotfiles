# tener dotfiles

個人用の `denix` ベース multi-host dotfiles です。  
NixOS と `nix-darwin` を 1 つの flake で管理し、Home Manager は各 system に統合しています。

汎用テンプレートではなく、自分のホストと普段使う GUI/CLI、Neovim、Niri 周りに最適化した repo です。

## Host

- `nixos`: x86_64 Linux laptop
- `nvidia-desktop`: x86_64 Linux desktop
- `nixos-server`: x86_64 Linux headless server
- `wsl`: x86_64 Linux NixOS-WSL environment
- `macbook`: aarch64 Darwin laptop

## Architecture

- [flake.nix](./flake.nix): flake entrypoint。`denix.lib.configurations` で host/module を束ねる
- [hosts](./hosts): host 名、種別、system、rice や boot のような host 固有 metadata と hardware import だけを置く薄い定義
- [modules](./modules): denix が自動発見する shared / host-specific module
- [rices](./rices): denix の rice 定義。共通 wallpaper と macOS の WM variant を切り替える
- [home/home.nix](./home/home.nix): 共通 Home Manager 設定
- [lib](./lib): denix が自動発見しない内部 helper。大きくなりやすい package 群、生成ロジック、host 固有 helper を module から明示 import する
- [config](./config): Neovim、fish、niri、Rift、waybar などの実ファイル
- [packages](./packages): 軽い独自 package 定義
- [legacy](./legacy): 退避した旧構成。現行 flake では未使用

`hosts/` と `modules/` と `rices/` は `denix` が自動で読むので、新しい `.nix` を足したら Git 管理下に置く前提です。
`lib/` は自動発見されないので、module を肥大化させる実装詳細や package 集約を置き、必要な module から明示的に `import` します。
NixOS host の `hosts/*/hardware-configuration.nix` は `flake.nix` 側で自動除外しているので、host 追加時に除外リストを手で更新する必要はありません。
Darwin の共通土台は [modules/darwin-base.nix](./modules/darwin-base.nix)、`macbook` 固有の UX 調整は [modules/darwin-host-macbook.nix](./modules/darwin-host-macbook.nix) に寄せています。
macOS の GUI アプリは「cross-platform なものは Nix、App Store / cask-first なものは Homebrew」を目安に分けています。
`macbook-mac` は Rift / AeroSpace を使わない native macOS fallback rice です。

## Codex

`macbook` では Homebrew cask で `codex-app` に加えて `codex` CLI も入れる運用です。
`nh darwin switch . -H macbook-rift` 後は terminal から `codex` をそのまま叩けます。
`nvidia-desktop` では Nixpkgs の `codex` CLI を Home Manager で入れ、fish の `codex` function で `-a never -s danger-full-access` を既定にしています。
この host では `tener` の sudo も passwordless にしているので、Codex からの `sudo` 実行でパスワード入力を求められません。

初回ログインだけは別途必要です。ブラウザ認証を使うなら:

```sh
codex login
```

`OPENAI_API_KEY` を使うなら、普段どおり `~/.config/fish/secrets.fish` などで環境変数を読み込んだうえで:

```sh
printenv OPENAI_API_KEY | codex login --with-api-key
```

## NixOS-WSL

Windows 側で NixOS-WSL を入れたら、この repo の `wsl` host で初回 boot します。
`wsl.defaultUser` を `nixos` から `tener` に変える初回だけは、NixOS-WSL の手順に合わせて `switch` ではなく `boot` を使います。

初回の NixOS shell はまだ `nixos` user なので、一時 clone から boot generation を作ります。

```sh
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git -c git clone https://github.com/tenelol/.dotfiles.git /tmp/dotfiles
cd /tmp/dotfiles
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#nh -- os boot . -H wsl
```

PowerShell 側で一度止めて、root で新 generation を通してからもう一度止めます。

```powershell
wsl -t NixOS
wsl -d NixOS --user root exit
wsl -t NixOS
```

次回からは `tener` user で入れるので、通常の場所に clone して `nh` で運用します。

```sh
git clone https://github.com/tenelol/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
nh os switch . -H wsl
```

`wsl` host は NixOS-WSL module を import し、Windows interop、Windows PATH、Windows ssh-agent passthrough、`/mnt` automount を有効にします。
WSL では不要な常駐 service を避けるため、共通 Linux base の `zramSwap` と `tailscale` はこの host だけ無効化しています。

## Raycast

`macbook` では Raycast を Homebrew cask で入れています。Window Management は Raycast 側で hotkey を割り当て、Script Commands はこの repo から配る前提です。

Script Commands は `~/.config/raycast/scripts` に展開されるので、Raycast の `Extensions` → `Script Commands` でその directory を追加すると使えます。

最初に入れてある個人用コマンド:

- `Dotfiles: Rebuild macbook`: Terminal.app を開かずに、現在の rice を保った `nh darwin switch` を裏で実行する。AeroSpace process/config や現在の wallpaper から `macbook-rift` / `macbook-aerospace` のような rice 付き config を指定し、管理者権限が必要なときだけ macOS の認証ダイアログを出す
- `Apps: Open Ghostty`: Ghostty を新しく開く。Raycast の `Extensions` → `Script Commands` → `Open Ghostty` で hotkey を割り当てる

`Dotfiles: Rebuild macbook` の実行ログは `~/Library/Logs/dotfiles/macbook-switch-latest.log` に置き、重複起動は lock と実行中の rebuild/switch process 確認で防いでいます。

## Cross-device clipboard

`nvidia-desktop` では KDE Connect を有効化し、niri 起動時に `kdeconnect-indicator` を起動します。KDE Connect の NixOS module が `kdeconnect-kde` を入れ、TCP / UDP `1714-1764` を開けるので、niri/Wayland でも同一 LAN 上の device と clipboard sharing を使えます。

`macbook` 側の KDE Connect は Homebrew cask や Nixpkgs の Darwin package としては管理できないため、公式 nightly の ARM 版を手動で入れます。導入後、`nvidia-desktop` と `macbook` をペアリングし、両側で Clipboard plugin を有効にします。

## Remote builds

PC の負荷を下げるため、interactive host の `macbook` / `nixos` / `nvidia-desktop` では `nixbuild.net` を Nix remote builder として有効化しています。`nixbuild.net` は Linux target 用なので、Darwin system rebuild 自体はローカル build のままですが、`macbook` から Linux derivation を build するときは `x86_64-linux` / `aarch64-linux` を offload できます。

秘密鍵は repo に置かず、`nix-daemon` を実行する root user から読める場所に置きます。既定の配置:

- NixOS: `/root/.ssh/nixbuild_ed25519`
- macOS: `/var/root/.ssh/nixbuild_ed25519`

鍵は passphrase なしの Ed25519 で作り、public key を `nixbuild.net` に登録します。

```sh
sudo mkdir -p /var/root/.ssh
sudo ssh-keygen -t ed25519 -N "" -f /var/root/.ssh/nixbuild_ed25519 -C macbook-nixbuild
sudo cat /var/root/.ssh/nixbuild_ed25519.pub
sudo ssh eu.nixbuild.net shell
```

NixOS では path だけ `/root/.ssh/nixbuild_ed25519` に置き換えます。`nixbuild.net` を使う host は local build pressure を抑えるため `max-jobs = 1` を既定にしています。host ごとに無効化したい場合は `myconfig.nixbuild.enable = false;`、鍵 path を変える場合は `myconfig.nixbuild.identityFile` を上書きします。

## Workflow

リポジトリの構造と現在の構成をブラウザで確認する:

```sh
nix develop
```

対話シェルに入ると `http://127.0.0.1:43110` で Dotfiles Explorer が起動し、ブラウザも開きます。
`hosts/`、`modules/`、`rices/`、flake inputs、Homebrew / Nix package、Git の変更状態をリポジトリから都度読み取るため、設定を編集すると画面も自動更新されます。
ブラウザを開きたくない場合は `DOTFILES_EXPLORER_NO_OPEN=1 nix develop`、port を変える場合は `DOTFILES_EXPLORER_PORT=43111 nix develop` を使います。
シェルを抜けると、そのシェルが起動したローカルサーバーも終了します。

軽量評価:

```sh
./scripts/validate eval
```

構造チェックだけを先に見る:

```sh
./scripts/validate structure
```

ローカル環境の診断:

```sh
dotfiles doctor
```

`dotfiles doctor` は repo の場所、Git の dirty 状態、`nix` / `nh`、flake metadata / configuration 名の軽量評価、実行中の rebuild/switch process、macOS では active rice 推定・Raycast script・SketchyBar・switch log をまとめて確認します。更新、build、switch は実行しません。warning も失敗扱いにしたいときは `dotfiles doctor --strict`、flake 評価を省くときは `dotfiles doctor --no-eval` を使います。

Darwin 実機がまだ無い段階でも `macbook` host を腐らせないため、普段の軽量チェックは Linux / Darwin をまとめて見る `./scripts/validate eval` を基準にします。
このコマンドは active Nix ファイルの肥大化チェックを通してから、`nix flake check --all-systems --no-build` で Linux の全 host / rice 派生と、実運用する Darwin target（`macbook-rift` / `macbook-aerospace` / `macbook-mac`）を build なしで評価します。未使用の Darwin rice も flake output には残るため、必要なときは `nh darwin build . -H <target>` で個別確認できます。
CI の pull request では `nix fmt --ci` と `./scripts/validate eval` だけを走らせ、GitHub 上の待ち時間を軽くしています。Linux host の実 build は `main` への push と `workflow_dispatch` で `checks.x86_64-linux.build-*` を個別に build します。ローカルの実運用は引き続き `nh os build` / `nh darwin build` を使います。Darwin は GitHub Actions の Linux runner では build せず、ローカルで `./scripts/validate darwin` を回す運用です。

整形確認:

```sh
nix fmt -- flake.nix hosts modules rices home packages lib --ci --excludes 'hosts/*/hardware-configuration.nix' --excludes 'legacy/**'
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
nh os switch . -H wsl
```

macOS host を build / switch:

```sh
if pgrep -f '(^|[[:space:]/])(nh[[:space:]]+(os|darwin)[[:space:]]+(build|switch)|darwin-rebuild[[:space:]]+(build|switch)|nixos-rebuild[[:space:]]+(build|switch))([[:space:]]|$)' >/dev/null; then
  echo "another rebuild or switch is already running" >&2
else
  if pgrep -qx AeroSpace || [ -e ~/.config/aerospace/aerospace.toml ]; then
    rice="aerospace"
  else
    rice="rift"
  fi
  target="macbook-${rice}"
  ./scripts/validate darwin
  nh darwin build . -H "$target"
  nh darwin switch . -H "$target"
fi
```

macOS に初回導入するときは、まず upstream Nix を入れてからこの repo を初回 switch します。
この repo は `nix-darwin` 側で `nix.*` を管理しているので、Determinate installer を使う場合も upstream Nix を選ぶ前提です。

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --prefer-upstream-nix
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
cd ~/.dotfiles
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
sudo nix run github:nix-darwin/nix-darwin#darwin-rebuild -- switch --flake .#macbook-rift
```

初回は Homebrew を公式インストーラで入れてから `switch` します。以降の cask 管理は既存の `homebrew.*` 設定に寄せています。
その後は `nh` と `darwin-rebuild` が入るので、通常の rebuild / switch では現在の desktop 状態から rice 付き config を組み立てて指定します。

rice を切り替えて build:

```sh
nh darwin build . -H macbook-rift
nh darwin build . -H macbook-aerospace
nh darwin build . -H macbook-mac
```

`nh` を使う前提で書いています。`nixos-rebuild` や `darwin-rebuild` を直接叩くより、普段の運用では `nh` を優先します。
共通の評価入口として `./scripts/validate` を置いていて、`eval` / `linux` / `darwin` の 3 モードを使い分けます。
手動で rebuild / switch するときも、実行前に既存の rebuild/switch process がないか確認し、AeroSpace process/config や現在の wallpaper から組み立てた config 名を `-H` に渡して現在の rice を保ちます。
通常の `nixos` / `nvidia-desktop` は `indigo` rice を使い、`macbook` の通常運用は `macbook-rift` として明示します。`macbook-rift` は `img/rift.png`、`macbook-aerospace` は `img/aerospace.png` を使い、SketchyBar の文字色/accent、Ghostty foreground、JankyBorders の色も rice から切り替えます。Linux desktop では `switch` 後に Home Manager activation が `apply-theme-wallpaper` を叩くので、`niri` 上でも wallpaper が即時反映されます。headless な `nixos-server` と NixOS-WSL の `wsl` にも rice 名は付きますが、今のところ見た目には影響しません。

## Design Notes

- 共通プロフィール値は [flake.nix](./flake.nix) の `profile` に集約
- Home Manager は standalone `homeConfigurations` ではなく system 側に統合
- bootloader のような machine 固有前提は host metadata で明示し、共通 base module に埋め込まない
- 外部バイナリに依存する integration は explicit allowlist に寄せ、将来 host を足しても暗黙に広げない
- Linux desktop は `niri` 前提
- macOS desktop は通常 `Rift` 前提。外部ディスプレイで Rift が不安定なときは `macbook-aerospace` rice で AeroSpace に切り替える。WM を使わず素の macOS に戻したいときは `macbook-mac` を使う
- Rift は `scrolling` を既定にして niri 風の column workflow に寄せる。`Alt+h/l` で column 間 focus、`Alt+Ctrl+Left/Right` で strip scroll、`Alt+Ctrl+Up/Down` で center/snap。3 本指 horizontal swipe は Rift の virtual workspace 移動に使う
- 外部ディスプレイで `scrolling` が不安定なときは `Alt+b` で一時的に `bsp` へ戻す
- `nixos.base` は全 NixOS host 共通、desktop 前提は host 非 server の module に分離
- `wsl` は NixOS-WSL 前提の server host として扱い、GUI/desktop module を避けて CLI と Home Manager を共有する
- macOS でも同じ Neovim 設定を使う。clipboard や language toolchain は Nix 側で揃える
- active Nix ファイルは 500 行を上限にし、超えそうな package 群、生成ロジック、inline script は `lib/` や `config/` へ逃がす

## Editing Notes

- repo の説明を書くときは「個人用」「denix で host/module を自動発見」「`nh` で build/switch」を前提にする
- 新しい host を追加するときは `hosts/<name>/default.nix` を作り、必要なら hardware config を同階層に置く
- 新しい module は `modules/` に置けば denix が拾う
- 新しい helper は `lib/` に置き、denix に自動発見させたい module だけを `modules/` に置く
