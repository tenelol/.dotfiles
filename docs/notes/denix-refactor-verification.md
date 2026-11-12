# denix リファクタリングの検証方法と見送り事項

2026-11-12 に denix の記法をそろえるリファクタリング（`refactor/denix-cleanup`）を行った。挙動を変えないことを、全12構成の `system.build.toplevel` の derivation で確かめた。

## 検証方法

- Linux の7構成（`surface`、`nvidia-desktop`、`wsl` と rice の組み合わせ）は drvPath の完全一致で確認できる。
- macOS の5構成は drvPath を直接比べられない。`modules/vault-context` の `vault-context-dotfiles-integration-check` がリポジトリ全体を入力に取るため、docs だけのコミットでも drvPath が変わる。
- そこで macOS は derivation の閉包を比べた。`nix derivation show -r` の結果から、flake ソースのストアパス（`<hash>-source` と、そのコピーの `<hash>-<hash>-source`）だけを定数に置き換え、依存先の出力パスを依存先の指紋に置き換えて、再帰的にハッシュを取る。`inputSrcs` はハッシュ順に並ぶので、置き換えた後に並べ直す。
- この比較は `files/` 配下の中身の変更を検出しない。`.nix` だけを変えるリファクタリング向けの方法である。

## 検証で見つかった落とし穴

- `home.packages` の並び順は profile の derivation に含まれる。リストをまとめ直すときは順序を保つ。
- `libreoffice` と `libreoffice-stable` は drvPath が同じでも `meta.priority` が違い、profile 内の順序が変わる。`libreoffice-fresh` の移行先は `libreoffice-stable` にした。
- nixfmt は `''` 文字列の先頭の空白を詰める。シェルスクリプトに空白込みの断片を差し込むときは `"..."` を使う。

## 見送った項目

- macOS と Linux のパッケージリストの共通化、`rift`・`sketchybar`・`jankyborders` の二重インストールの解消は、profile の順序や内容が変わるので見送った。
- herdr のバージョン確認の共通化と、`nixos.base`・`darwin.base` の共通部分の切り出しは、行数が減らずファイルが増えるだけなので見送った。
- `codex-skills` と `pi-coding-agent` の `home.ifEnabled.imports` は、denix の文書が避けるよう書いている形である。Home Manager を NixOS／nix-darwin に統合している間だけ動く。standalone の `homeConfigurations` を出すときは `home.always.imports` に直す必要がある。
- 次は所有者の判断待ちである。`module-scope` 拡張の全廃、`hostTraits.macbook` の features への置き換え、ホスト専用モジュールの扱い、既定で無効な `karabiner` と `persona-quickshell` の削除、移行用の掃除スクリプトの削除、`fullDesktop` の扱い。
