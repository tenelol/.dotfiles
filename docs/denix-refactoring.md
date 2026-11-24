# 挙動を変えない denix リファクタリング

`.nix` の書き方だけを変えるリファクタリングで、挙動が変わっていないことを確かめる方法と、見送った変更・未決の項目を残す。2026-11-12 の記法の統一（`refactor/denix-cleanup`）で使った。

## 検証方法

全構成の `system.build.toplevel` の derivation を、変更の前後で比べる。

- Linux の構成は drvPath の完全一致で確かめられる。
- macOS の構成は drvPath を直接比べられない。`modules/vault-context` の `vault-context-dotfiles-integration-check` がリポジトリ全体を入力に取るため、docs だけのコミットでも drvPath が変わる。
- そこで macOS は derivation の閉包を比べる。`nix derivation show -r` の結果から、flake ソースのストアパス（`<hash>-source` と、そのコピーの `<hash>-<hash>-source`）だけを定数に置き換え、依存先の出力パスを依存先の指紋に置き換えて、再帰的にハッシュを取る。`inputSrcs` はハッシュ順に並ぶので、置き換えた後に並べ直す。
- この比較は `files/` 配下の中身の変更を検出しない。`.nix` だけを変えるリファクタリング向けの方法である。

## 落とし穴

- `home.packages` の並び順は profile の derivation に含まれる。リストをまとめ直すときは順序を保つ。
- `libreoffice` と `libreoffice-stable` は drvPath が同じでも `meta.priority` が違い、profile 内の順序が変わる。`libreoffice-fresh` の移行先は `libreoffice-stable` にした。
- nixfmt は `''` 文字列の先頭の空白を詰める。シェルスクリプトに空白込みの断片を差し込むときは `"..."` を使う。

## 見送った変更

- macOS と Linux のパッケージリストの共通化、`rift`・`sketchybar`・`jankyborders` の二重インストールの解消は、profile の順序や内容が変わる。
- herdr のバージョン確認の共通化と、`nixos.base`・`darwin.base` の共通部分の切り出しは、行数が減らずファイルが増えるだけになる。
- `codex-skills` と `pi-coding-agent` の `home.ifEnabled.imports` は、denix の文書が避けるよう書いている形である。Home Manager を NixOS／nix-darwin に統合している間だけ動く。standalone の `homeConfigurations` を出すときは `home.always.imports` に直す必要がある。

## 未決

所有者の判断待ち: `module-scope` 拡張の全廃、`hostTraits.macbook` の features への置き換え、ホスト専用モジュールの扱い、既定で無効な `karabiner` と `persona-quickshell` の削除、移行用の掃除スクリプトの削除、`fullDesktop` の扱い。
