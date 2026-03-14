# NixOS dotfiles

このリポジトリは、NixOS のマルチホスト構成と Home Manager の設定をまとめた `.dotfiles` です。

## 構成

- `flake.nix`: NixOS flake のエントリ。`nixosConfigurations` を定義
- `hosts/`: ホスト別の NixOS 設定
- `home/`: Home Manager のエントリとモジュール
- `config/`: 各種アプリ設定 (`nvim`, `fish`, `niri`, `waybar` など)
- `modules/`: denix ベースのモジュール群
- `legacy/`: 旧構成の退避先。現行の flake からは未使用

## 前提

- Nix と Flakes が有効な NixOS
- `home-manager` は flake 経由で使用

## 使い方

ホストに合わせて `nixos-rebuild` を実行します。

`nixos` ホスト:

```sh
sudo nixos-rebuild switch --flake .#nixos
```

別ホストの場合:

```sh
sudo nixos-rebuild switch --flake .#nvidia-desktop
sudo nixos-rebuild switch --flake .#nixos-server
```

構成の評価だけをしたい場合:

```sh
nix flake check
```

フォーマット:

```sh
nix fmt
```

## メモ

- `home/home.nix` が `tener` ユーザーの Home Manager 設定の入口です。
- ホスト固有の設定は `hosts/<host>/` 配下にあります。
- `modules/` 配下の denix モジュールが各ホスト / Home Manager 設定を組み立てます。
- 新しい `.nix` ファイルを `modules/` や `hosts/` に追加した場合、flake から確実に見えるよう Git 管理下に置いておくのが安全です。
- Home Manager 管理下のアプリ設定は、基本的に `xdg.configFile` / `home.file` で宣言的に配置しています。
