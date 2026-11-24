# macOS の不具合の手がかり

実装を読んでも気づきにくい不具合の、切り分け方と対処を残す。

## Vicinae の初回起動でキーチェーンへの保存に失敗する

- 症状: Vicinae の server が起動直後に SIGABRT で落ちる。上流の database-key の処理で、新しいマスターキーをキーチェーンへ保存する経路が失敗している。QML のコンパイル失敗ではない。
- 切り分け: `security show-keychain-info` が認証エラーを返すかを見る。Security API の状態が unlocked でも失敗することがある。Apple Developer Forums に似た報告があるが、同じバグとは確定していない。
- 対処: Touch ID ではなく Mac のログインパスワードで画面ロックを解除すると、`security show-keychain-info` と Vicinae の起動が成功した（2026-10-14）。キーチェーンの削除、暗号化の無効化、パッケージの再ビルドは要らなかった。キーチェーンやデータベースを消して回避しない。
- 調べている間は、再起動のループを避けるため launchd agent `org.nix-community.home.vicinae` を一時的に bootout し、直ったら既存の plist を bootstrap して戻す。
- 定義: `modules/vicinae/default.nix`。
- 未解決: 配布された Nix の `.app` は、codesign の検証でリソース封印のエラーを返す。起動には影響しないが、原因は切り分けていない。

## nix-darwin が activation script を実行しない

- nix-darwin の `activate` に入るのは、`preActivation`・`extraActivation`・`postActivation` などの決まった名前だけ。`system.activationScripts.<任意の名前>` は警告もなく捨てられる（nix-darwin の `modules/system/activation-scripts.nix`）。Home Manager の `home.activation` は任意の名前でよい。この形で書いた処理が一度も動いていなかったことがある（`2efa944`）。
- 確かめ方: `nix eval .#darwinConfigurations.<target>.config.system.activationScripts.script.text` の出力に、書いた処理が入っているかを見る。
- `activate` はビルド時に `shellcheck --exclude=SC2016,SC1112` を通り、warning でもビルドが失敗する。要素が1つの `for` ループ（SC2043）で switch が止まったことがある。上の出力を同じオプションの shellcheck にかければ、ビルドの前に確かめられる。
