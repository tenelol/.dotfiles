---
name: proxmox-pve
description: "個人のProxmox VEノード・VM・LXCをAPIやshellで調査・操作するときに使う。"
---

# Proxmox VE Operations

個人のProxmox VEノード・VM・LXCを現在のAPI・runtime evidenceで確認し、依頼範囲の操作を行う。

- 対象nodeとVM/LXCの識別子を確定してから操作する。認証値はログ・成果物・contextへ出力しない。
- 基本操作の参照にあるAPI/CLIを使い、初期設定やTailscaleの手順はその変更を依頼された場合だけ読む。
- read-only調査から始め、停止・削除・構成変更等は既存の許可範囲を確認する。承認済みの操作を再承認待ちにしない。
- networkやstorageの変更では現在の接続経路と対象を確認し、host security controlを回避しない。

## 必要な操作だけ読む

該当する操作の参照だけ読み、別の操作の手順は必要になった時点で開く。

| 操作・条件 | 参照 |
| --- | --- |
| 接続先・API・shellの基本操作 | [手順](references/operations.md) |
| SSHの設定・診断 | [手順](references/ssh.md) |
| PVE host上のTailscale | [手順](references/tailscale.md) |
| 運用上の既定値と操作例 | [手順](references/examples.md) |
