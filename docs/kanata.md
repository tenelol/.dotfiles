# Kanata と VirtualHIDDevice driver

macOS のキー変換は Kanata に一本化し、出力に使う Karabiner の VirtualHIDDevice driver だけを単体で入れる。Karabiner-Elements 本体は入れない。

## 構成

- Kanata の公式バイナリ: [`packages/kanata-with-cmd.nix`](../packages/kanata-with-cmd.nix)。
- 署名付きの driver 単体 pkg と、互換性のための版固定: [`modules/darwin-installers/default.nix`](../modules/darwin-installers/default.nix)。既存の同版 driver は再インストールせず引き継ぐ。
- driver の常駐 daemon と、Karabiner-Elements 本体からの移行: [`modules/kanata/default.nix`](../modules/kanata/default.nix)。本体の SMAppService 登録を解除し、driver の自動起動を denix の `launchd.daemons.kanata-vhid` へ移す。ユーザーの Karabiner 設定は消さない。
- 単体 driver の構成と起動手順は [Kanata の macOS setup](https://github.com/jtroo/kanata/blob/v1.12.0/docs/setup-macos.md) と [driver の公式手順](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/tree/v6.14.0#usage) に従う。

## 制約

- Kanata と driver の protocol の版を合わせる。Kanata 1.12.0 は Karabiner-Elements 16.3.0 に同梱の daemon 8.5.0 に接続できず、物理キーボードの入力も手放した。
- Karabiner-Elements 本体を入れない。本体の Core Service も物理キーボードを取り合い、英数キーなどが二重に入力される。`launchctl disable` しても、本体の起動に伴ってサービスが再登録された。
- 公式の `uninstall.sh` は driver も消すので使わない。driver 自体の削除・deactivate はしない。

## 版を上げるとき

- Kanata の release note で、上げる先の driver protocol に対応したかを確かめてから、Kanata と driver の組み合わせを決める。main branch の文書に書かれただけでは、安定版が出たと判断しない。本体のインストールで解決しようとしない。
- 入っている driver の版は `pkgutil --pkg-info org.pqrs.Karabiner-DriverKit-VirtualHIDDevice` で確かめる。
- 上げたあと、Caps と f/v のレイヤーが動くことを実機で確かめる。
