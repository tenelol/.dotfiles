# Kanata と Karabiner の driver 互換性

Kanata 1.12.0 は Karabiner の VirtualHIDDevice 6.14.0 と組み合わせて使う。Karabiner-Elements を 16.0.0 から上げると driver も更新され、Kanata が出力できなくなる。

## 経緯・判断・理由

- 2026-09-14、Karabiner-Elements を 16.3.0 へ更新すると VirtualHIDDevice の daemon が 8.5.0 になった。Kanata 1.12.0 は出力 backend に接続できず、物理キーボードの入力も手放した。16.0.0 に戻すと driver の版が一致して復旧した。
- 当時、Kanata の main branch の setup 文書は新しい driver protocol への対応を将来の 1.13.0 として書いていた。文書の記載だけで安定版が出たとは判断しない。
- Karabiner の Core Service も物理キーボードを取り合う。Kanata を有効にしている間は Core Service を無効にし、VirtualHIDDevice の daemon だけ残す（`effcff9`）。

## 現状

- Kanata: `packages/kanata-with-cmd.nix`（公式の macOS バイナリ）。
- Karabiner: `modules/darwin-installers/default.nix` が 16.0.0 の公式 pkg を入れ、receipt で Karabiner-Elements 16.0.0 と VirtualHIDDevice 6.14.0 を確かめる。`strictVersion` のため、アプリ自身の更新などで新しい版が入っていると activation が失敗する。
- Core Service の無効化と復元: `modules/kanata/default.nix`。

## 版を上げるとき

- Kanata の release note で、上げた先の VirtualHIDDevice（driver protocol）に対応したかを確かめ、Kanata と Karabiner を一緒に上げる。片方だけ上げない。
- 入っている driver の版は `pkgutil --pkg-info org.pqrs.Karabiner-DriverKit-VirtualHIDDevice` で確かめる。
- 上げたあと、Caps と f/v のレイヤーが動くことを実機で確かめる。
