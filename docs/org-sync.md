# org ファイルの iCloud Drive 同期

メモは org-mode で書き、Mac の Neovim と iPhone の自作アプリ Orgnote が iCloud Drive の `org` フォルダを読み書きする。ホームの `org` ディレクトリはそのフォルダへの symlink で、Home Manager では管理していない。

## 方針

- メモに求めるのは素早いキャプチャと iCloud での共有で、Apple 標準メモ固有の機能（共有シート、Siri、手書きなど）は使わない。標準メモを Neovim から編集する試み（apple-notes.nvim と自作の memo-sync）は、保存時の本文消失と Notes の書込 API の制約で撤去した（`0c1d9b1`、`201fa4a`）。
- 同期にはサーバーを立てず iCloud Drive を使う。使うのは iPhone と Neovim だけで、Nextcloud はメモアプリとしては使いにくいため、Nextcloud や Syncthing は採らない。

## 構成

- Neovim: `modules/nvim/files/lua/plugins/orgmode.lua` の `org_agenda_files` と `org_default_notes_file` が symlink 越しのパスを使う。
- iPhone: Orgnote は別の repository。無料の Personal Team の署名は7日で切れるため、`modules/ios-refresh` の launchd agent が定期的に再署名して再インストールする。

## 注意

- symlink の向きは「ホーム → iCloud Drive」にする。iCloud Drive の中に置いた symlink は同期されない。
- 宣言化していないので、新しい Mac では symlink を手で作る。
- `home.file."org"` などで宣言化すると既存の symlink と衝突する。宣言化するなら、手動の symlink を外してから `mkOutOfStoreSymlink` で同じ iCloud Drive のフォルダを指す。
