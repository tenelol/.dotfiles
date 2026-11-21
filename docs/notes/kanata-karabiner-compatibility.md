# Kanata と Karabiner の driver 互換性

macOS のキー変換は Kanata に一本化し、出力に必要な VirtualHIDDevice driver だけを単体導入する。Karabiner-Elements 本体は入れない。

## 経緯・判断・理由

- 2026-09-14、Karabiner-Elements を 16.3.0 へ更新すると VirtualHIDDevice の daemon が 8.5.0 になった。Kanata 1.12.0 は出力 backend に接続できず、物理キーボードの入力も手放した。16.0.0 に戻すと driver の版が一致して復旧した。
- 当時、Kanata の main branch の setup 文書は新しい driver protocol への対応を将来の 1.13.0 として書いていた。文書の記載だけで安定版が出たとは判断しない。
- Karabiner の Core Service も物理キーボードを取り合う。Kanata を有効にしている間は Core Service を無効にし、VirtualHIDDevice の daemon だけ残す（`effcff9`）。
- 2026-11-21、全アプリで英数キーも二重入力になり、Core Service の停止で解消した。`launchctl disable` 後にも本体の起動に伴うサービス再登録を観測したため、本体を残して停止する構成をやめ、動作していた driver の版を維持して単体導入へ移行した。

## 現状

- Kanata の公式バイナリ: [`packages/kanata-with-cmd.nix`](../../packages/kanata-with-cmd.nix)。
- 署名付きの driver 単体 pkg と互換性のための版固定: [`modules/darwin-installers/default.nix`](../../modules/darwin-installers/default.nix)。既存の同版 driver は再インストールせず引き継ぐ。
- driver の常駐 daemon と本体からの移行: [`modules/kanata/default.nix`](../../modules/kanata/default.nix)。本体の SMAppService 登録を解除し、driver の自動起動を denix の `launchd.daemons.kanata-vhid` へ移す。ユーザーの Karabiner 設定は消さない。
- 公式の `uninstall.sh` は driver も消すため、この移行には使わない。driver 自体の削除・deactivate は行わない。
- 単体 driver の構成と起動手順は [Kanata の macOS setup](https://github.com/jtroo/kanata/blob/v1.12.0/docs/setup-macos.md) と [driver の公式手順](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/tree/v6.14.0#usage) に従う。

## 版を上げるとき

- Kanata の release note で、上げた先の VirtualHIDDevice（driver protocol）に対応したかを確かめ、Kanata と driver の組み合わせを決める。本体のインストールで解決しようとしない。
- 入っている driver の版は `pkgutil --pkg-info org.pqrs.Karabiner-DriverKit-VirtualHIDDevice` で確かめる。
- 上げたあと、Caps と f/v のレイヤーが動くことを実機で確かめる。
