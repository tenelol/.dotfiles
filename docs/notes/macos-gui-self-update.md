# macOS GUI アプリの自己更新への移行

GUI アプリは Nix を最低の版として入れ、アプリ自身の更新を許す通常配置にした（README の macOS packages 節）。移行で分かった、実装からは読み取れない制約を残す。

## 経緯・判断・理由

- 最新版をすぐ使いたいアプリがあり、2026-10-04〜05 に対象を「GUI の更新ボタンで中身を更新できるもの全て」へ広げた（`84bc96c`、`00cdc3d`、`8ad7c3b`）。
- Docker Desktop の更新を止める設定 hook は、Group Container の同期読み取りで待ち続けて activation を止めた。hook を外し、Docker 自身の GUI で更新確認を有効にした（`3c4b675`）。他のアプリの保護されたデータを読む hook は増やさない。
- macOS では、エージェントから見た `os.access` の結果と、アプリ自身が実際に書き込めるかが一致しないことがあった。
- ChatGPT Classic の共有 Group Container は保護されていてバックアップできず、移行では触らなかった。

## 現状

- 対象の一覧は `modules/darwin-installers/files/apps.json`、生成は `packages/macos-apps.nix`、配置と照合は `modules/darwin-installers/files/reconcile.py`。
- Docker の更新設定 hook が無いことは `modules/darwin-installers/tests/self-updating.nix-test` で確かめている。

## 再発時の手がかり

- 書き込めるかどうかは、配置、所有者、mode、署名と、公式アップデーターの実際の動作を分けて確かめる。
- activation の失敗は `dotfiles-installers --plan` の read-only な計画で切り分ける。
- 最初の移行の前にアプリを終了する。ブラウザーのプロフィールやキーチェーンは既存の場所のまま使う。
