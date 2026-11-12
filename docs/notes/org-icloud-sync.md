# org ファイルの iCloud Drive 同期

ホームの `org` ディレクトリは iCloud Drive の `org` フォルダへの symlink で、Home Manager では管理していない。iPhone の自作アプリ Orgnote が同じフォルダを読み書きする。

## 経緯・判断・理由

- メモに求めるのは素早いキャプチャと iCloud での共有で、標準メモ固有の機能（共有シート、Siri、手書きなど）は使わない。書く場面に Neovim を介在させたいことと、標準メモへの橋渡しの制約（[apple-notes-bridge-retrospective.md](./apple-notes-bridge-retrospective.md)）から、2026-10-16 に org-mode と自作の iPhone アプリへ移った。
- 同期にはサーバーを立てず iCloud Drive を使う。Nextcloud や Syncthing も検討したが、使うのは iPhone と Neovim だけで、Nextcloud はメモアプリとしては使いにくいと判断した。
- 2026-10-17 に既存の `org` ディレクトリをバックアップしてから iCloud Drive へ移し、元の場所に symlink を作った。

## 現状

- Neovim: `modules/nvim/files/lua/plugins/orgmode.lua` の `org_agenda_files` と `org_default_notes_file` が symlink 越しのパスを使う。
- iPhone: Orgnote は別の repository。無料の Personal Team の署名は7日で切れるため、`modules/ios-refresh` の launchd agent が定期的に再署名して再インストールする。

## 再開時の手がかり

- symlink の向きは「ホーム → iCloud Drive」にする。iCloud Drive の中に置いた symlink は同期されない。
- `home.file."org"` などで宣言化すると既存の symlink と衝突する。宣言化するなら、手動の symlink を外してから `mkOutOfStoreSymlink` で同じ iCloud Drive のフォルダを指す。
- 宣言化していないので、新しい Mac では symlink を手で作る。
