# macOS の window manager（Rift・OmniWM）

rice ごとに window manager を選ぶ（README の Rice 節）。各 window manager のモジュールは、選ばれていないとき `darwin.ifDisabled` の `preActivation` で自分の launchd agent を bootout し、残ったプロセスを止める（`modules/desktop/default.nix` の `stopDarwinWindowManager`）。他の window manager の名前は持たないので、同時には動かない。

## Rift

- 三本指の workspace 切替のため、公式配布の 0.6.4 を使う（[`packages/rift.nix`](../packages/rift.nix)）。0.6.3 以降は scroll の action が無いと通常の workspace の action へフォールバックするので、独自パッチもソースからの再ビルドも要らない。0.5.8 系では scrolling layout の gesture が scrolling 用の handler にしか渡らず、scrolling の gesture を無効にすると通常の三本指切替も効かなかった。
- 設定は [`modules/rift/files/config.toml`](../modules/rift/files/config.toml)。`settings.layout.scrolling.gestures` は無効、`settings.gestures` は有効にする。
- 版を上げるときは、scrolling layout の上で、ウィンドウの上と空の workspace の両方から三本指で切り替えられるかを実機で確かめる。

## OmniWM

### 設定の管理

- 設定は [omniwm.nix](https://github.com/mst-mkt/omniwm.nix) の `programs.omniwm` で宣言する（[`modules/omniwm/default.nix`](../modules/omniwm/default.nix)）。同梱の既定 `settings.toml` に、既定と異なる値を書いた [`modules/omniwm/files/settings.toml`](../modules/omniwm/files/settings.toml) を重ねて毎 switch で書き出す。GUI で変えた値は次の switch で戻るので、残したい変更はこのファイルへ移す。
- `hotkeys` 以外のリストは既定を丸ごと置き換えるので、`appRules` と `workspaces` は既定と同じ項目も含めて全体を書く。未知のホットキー ID は評価時に失敗する。
- 壁紙から枠線を塗り直す `borders.color`・`borders.gradient`（[wallpaper-theming.md](./wallpaper-theming.md)）と、ディスプレイ UUID に結びつく `monitors`・`routing` は `preserveSettings` で実機の値を保つ。
- omniwm.nix へ移す前の実機の設定は `~/.config/omniwm/settings.toml.pre-omniwm-nix` に残してある。

### 配置と版の更新

- 画面収録の権限と Raycast からの発見のため、Nix store への symlink ではなく `/Applications/OmniWM.app` に通常配置する（`modules/darwin-installers/files/apps.json`、中身は omniwm.nix のパッケージ）。Home Manager 側にはアプリを入れず、launchd agent だけを `/Applications` の実行ファイルへ向ける。
- 版は flake 入力 `omniwm` で固定し、上げるときは omniwm.nix の入力を更新する。darwin-installers は起動中のアプリを上書きしないので、switch の前に OmniWM を正常終了する。正常終了では launchd が再起動しないため、switch 後に `launchctl kickstart gui/$(id -u)/org.nix-community.home.omniwm` で起動する。
- 0.8.0 は初回起動時に設定を schema 4 から 5 へ一方向に書き換え、`settings.toml.pre-v5` を残す。このファイルがある間は Settings に移行の通知が出続けるので、このMacでは `settings.toml.before-v5-20261119` に改名して残した。0.7.6 は schema 5 を読めないので、版を戻すときはこのバックアップを戻す。

### バーと枠線

- OmniWM の rice では SketchyBar と JankyBorders を無効にし、内蔵の workspace bar と枠線を使う（`rices/darwin/omniwm.nix`）。
- 0.8.0 からバーは OmniShell のスタイルが描き、スタイルの値が `[workspaceBar]` より優先される。既定のスタイルは幅いっぱいでメニューバーに重なり、macOS のメニューバー自動非表示を「常に」にするので、見た目は Settings > Styles & Widgets で整える（旧 Workspace Bar のページ。Hidden Bar は Menu Bar の下にある）。
- 配色は [wallpaper-theming.md](./wallpaper-theming.md)。
- Rift 固有のレイアウトや任意コマンドの起動は、別のキーボード daemon で真似しない。
