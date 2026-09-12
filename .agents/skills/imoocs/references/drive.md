# 授業に紐づくGoogle Drive資料

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## Google Drive

Use the native Drive collector for course handouts and sample data stored outside MOOCs pages:

```bash
imoocs drive ls
imoocs drive ls --match 'ソフトウェア・エンジニアリング'
imoocs drive collect --path /path/to/download-dir --match 'ソフトウェア・エンジニアリング'
imoocs drive collect --path /path/to/download-dir --parent '<drive-folder-url-or-id>' --recursive
```

The default Drive parent folder is:

```text
https://drive.google.com/drive/u/0/folders/1MDPeeFHJDmqgQeuJQOHPpWPLDyhT3ZSU
```

Drive commands use stored Google cookies from the same CLI cookie jar as slide collection. If Drive returns `auth_required` with `data.authScope: "google_drive"` or `data.cookieStore: "google_expired"`, run `imoocs auth import-browser --browser auto`, then retry the Drive command. If Chrome has multiple profiles and auto-detection fails, retry with `--browser chrome --profile 'Profile 2'` or the profile directory/name shown by Chrome. Do not run `imoocs auth login`, Keychain auth, GUI auth, BrowserUse, Playwright, or manual browser inspection for Drive-only failures unless the user explicitly authorizes that fallback in the current turn.

`imoocs drive collect --match <text>` treats matching direct child folders of the default parent as the selected course folder and collects their contents recursively. Without `--match` or `--recursive`, folders are listed or skipped rather than broadly downloading every course folder.
