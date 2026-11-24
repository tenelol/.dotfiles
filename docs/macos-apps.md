# 自己更新する macOS GUI アプリ

GUI の更新ボタンで中身を更新できるアプリは、Nix を最低の版として `/Applications` に通常配置し、アプリ自身の更新を許す。運用の概要は README の macOS packages 節にある。ここでは実装から読み取れない制約を残す。

## 構成

- 対象の一覧は [`modules/darwin-installers/files/apps.json`](../modules/darwin-installers/files/apps.json)、生成は [`packages/macos-apps.nix`](../packages/macos-apps.nix)、配置と照合は [`modules/darwin-installers/files/reconcile.py`](../modules/darwin-installers/files/reconcile.py)。
- Docker の更新設定 hook が無いことは `modules/darwin-installers/tests/self-updating.nix-test` で確かめている。

## 制約

- 他のアプリの保護されたデータ（Group Container など）を読む activation hook を作らない。Docker Desktop の更新を止める hook は Group Container の同期読み取りで待ち続け、activation を止めた。今は Docker 自身の GUI で更新確認を有効にしている（`3c4b675`）。
- ChatGPT Classic の共有 Group Container は保護されていてバックアップできない。
- macOS では、エージェントから見た `os.access` の結果と、アプリ自身が実際に書き込めるかが一致しないことがある。

## 不具合の切り分け

- 書き込めるかどうかは、配置、所有者、mode、署名と、公式アップデーターの実際の動作を分けて確かめる。
- activation の失敗は `dotfiles-installers --plan` の read-only な計画で切り分ける。
