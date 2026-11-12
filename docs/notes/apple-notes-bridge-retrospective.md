# Apple 標準メモ連携の撤去

Neovim から Apple 標準メモを編集する試み（apple-notes.nvim の導入と、自作の memo-sync）は、どちらも撤去した。メモは org-mode と iCloud Drive で扱う（[org-icloud-sync.md](./org-icloud-sync.md)）。

## 経緯・判断・理由

- 動機は、標準メモの素早い入力と iCloud 共有を保ったまま Neovim で書くこと。
- apple-notes.nvim は 2026-10-05 に入れた（`9969a29`）。保存した直後に既存メモの本文が半分以上消え、標準メモの取り消しでも戻らなかったため、同日に撤去した（`0c1d9b1`）。div と p が混ざった合成 HTML では、Markdown 変換の前処理で p ブロックが欠落した。導入時の検証は単純な div 形式しか試していなかった。
- 代わりに memo-sync を自作した（`a71a14f` から `d01f13c`）。登録したメモとローカルのファイルを双方向に同期し、原本の保存、CAS 照合、競合時の停止を備えたが、Notes の制約に合わせる処理が膨らんだ。
- 2026-10-16 に org-mode と自作の iPhone アプリへ方針を移し、2026-10-21 に module ごと削除した（`201fa4a`。件名は同時に入った別の変更のもので、削除の理由は書かれていない）。

## Notes の制約

再び Notes を扱うときの前提。

- スクリプトから書ける本文は HTML 全体の `body` だけ。`plaintext` は読み取り専用で、範囲を置換する API は無い。比較と書込を一体にするトランザクションも無く、同時編集の排他は保証できない。
- 普通の HTML 書込では連続スペースとタブが潰れる（`white-space: pre-wrap` で保持できた）。タイトルは取得時に太字の span へ正規化される。
- 添付のあるメモに `body` を書き戻すと、添付が複製されたり ID が変わったりする。画像を残すには、Accessibility API（`AXSelectedTextRange` / `AXSelectedText`）で本文の一部だけを置き換える必要があった。
- 表は添付扱いで、`plaintext` にセルの内容が出ない。番号付きリストとリンク先 URL は HTML 書込で失われる。共有メモ、ロックしたメモ、チェックリストは安全に書き戻せない。
- 全件のコレクションには、最近削除した項目と削除済みフォルダへの参照が一時的に残る。`exists()` で除外する。
- 実装と試験は `201fa4a` の親 commit の `modules/memo-sync/` に残っている（`git show 201fa4a^:modules/memo-sync/files/memo_sync.py` など）。

## 未解決

- apple-notes.nvim で本文が消えた直接の原因。実際のメモの保存前 HTML は取れていない。
- 別端末との iCloud の往復、共同編集、オフラインからの再接続は検証していない。
