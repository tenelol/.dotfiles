# azooKey

azooKey は公式の署名付き pkg を darwin-installers で入れる（[`modules/darwin-installers/default.nix`](../modules/darwin-installers/default.nix)）。入力ソースの設定は [`modules/azookey/default.nix`](../modules/azookey/default.nix)。パッチを当てたソースビルドは `3e0c42d` でやめた。

## 入力ソースの設定

- 公式版の `Info.plist` では、入力モード ID が `com.apple.inputmethod.Japanese` と `com.apple.inputmethod.Roman`。TIS の入力ソース ID は `dev.ensan.inputmethod.azooKeyMac.*` で、この2つは別物。
- `AppleEnabledInputSources` の `Input Mode` に `dev.ensan.*` を書くと、macOS が日本語モードを有効として扱わず、Control+Space で日本語に切り替わらなくなる（`f903a67`）。
- 英字モードは有効にしない。有効にすると Control+Space の切替先が ABC ではなく azooKey (English) になる（`f54686d`）。

## pkg を入れ替えるときの注意

- ad-hoc 署名のビルドが `/Library/Input Methods` にあると、darwin-installers は公式 pkg の導入を拒否する。先に退避する。
- darwin-installers は `pgrep -f azooKeyMac` で起動中かを判定する。引数にこの文字列を含むコマンド（switch の完了待ちの監視など）を switch 中に動かすと、誤検出で止まる。
- 同じ bundle ID のアプリが LaunchServices に複数登録されていると、macOS が古いほうを参照して入力ソースを外すことがある。`lsregister -dump` で確認し、不要な登録は `lsregister -u` で外す。
- 入れ替えの直後は IME が未起動・未登録のままになることがある。入力ソースの選択スクリプトが落ちたら、`TISRegisterInputSource` で登録してから選び直す。切替ポップアップに古い一覧が残ったときは、ログインし直すと消える。
