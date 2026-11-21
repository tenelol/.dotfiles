# macOS の実機トラブルの手がかり

実機でだけ起き、repository からは分からない不具合の切り分けを残す。

## Vicinae の初回起動でキーチェーンへの保存に失敗する

- 症状: Vicinae の server が起動直後に SIGABRT で落ちる。上流の database-key の処理で、新しいマスターキーをキーチェーンへ保存する経路が失敗している。QML のコンパイル失敗ではない。
- 2026-10-14 の事例では、Touch ID ではなく Mac のログインパスワードで画面ロックを解除したあと、`security show-keychain-info` と Vicinae の起動が成功した。キーチェーンの削除、暗号化の無効化、パッケージの再ビルドは不要だった。
- 切り分け: `security show-keychain-info` が認証エラーを返すかを見る。Security API の状態が unlocked でも失敗することがある。Apple Developer Forums に似た報告があるが、同じバグとは確定していない。
- 調べている間は、再起動のループを避けるため launchd agent `org.nix-community.home.vicinae` を一時的に bootout し、直ったら既存の plist を bootstrap して戻す。キーチェーンやデータベースを消して回避しない。
- 定義: `modules/vicinae/default.nix`。
- 未解決: 配布された Nix の `.app` は、codesign の検証でリソース封印のエラーを返していた。起動には影響しなかったが、原因は切り分けていない。

## nix-darwin が activation script を実行しない

- nix-darwin の `activate` に入るのは、`preActivation`・`extraActivation`・`postActivation` などの決まった名前だけ。`system.activationScripts.<任意の名前>` は警告もなく捨てられる（`modules/system/activation-scripts.nix`）。Home Manager の `home.activation` は任意の名前でよい。
- 2026-11-21 に、こうして一度も動いていなかった5つ（ログインシェル、スクリーンショットのフォルダ、メニューバーの再読み込み、yabai の掃除、AeroSpace へ切り替えるときの Rift の停止）を見つけた。必要なものは `postActivation`、または各 window manager の `ifDisabled` の `preActivation` へ移し、残りは消した。
- 確かめ方: `nix eval .#darwinConfigurations.<target>.config.system.activationScripts.script.text` の出力に、書いた処理が入っているかを見る。
