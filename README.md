# NixOS dotfiles

このリポジトリは、NixOS のマルチホスト構成と Home Manager の設定をまとめた `.dotfiles` です。

## 構成

- `flake.nix`: NixOS フレークのエントリ。`nixos` / `nvidia-desktop` / `nixos-server` を定義
- `hosts/`: ホスト別の NixOS 設定
- `home/`: Home Manager のエントリとモジュール
- `config/`: 各種アプリ設定 (nvim, fish, hypr, waybar など)

## 前提

- Nix と Flakes が有効な NixOS
- `home-manager` は flake 経由で使用

## 使い方

ホストに合わせて `nixos-rebuild` を実行します。

```bash
sudo nixos-rebuild switch --flake .#nixos
```

別ホストの場合:

```bash
sudo nixos-rebuild switch --flake .#nvidia-desktop
sudo nixos-rebuild switch --flake .#nixos-server
```

## メモ

- `home/home.nix` が `tener` ユーザーの Home Manager 設定の入口です。
- ホスト固有の設定は `hosts/<host>/` 配下にあります。
