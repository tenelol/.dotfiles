# macOS の window manager（Rift・OmniWM）

Rift は三本指の workspace 切替のため公式配布の 0.6.4 を使う。OmniWM は rice で試せるようにし、設定は初回だけ Rift 風に整えて、以後は GUI での変更を保つ。

## Rift

- 0.5.8 系では、scrolling layout の gesture が scrolling 用の handler だけに渡る。scrolling の gesture を無効にすると、通常の三本指 workspace 切替も効かなくなった。
- 0.6.3 以降は、scroll の action が無ければ通常の workspace の action へフォールバックする。ソースからの再ビルドを避けるため、独自パッチではなく公式配布の 0.6.4 を採用した（`9b9e185`）。ウィンドウの上と空の workspace の両方で直接切り替えられることを実機で確かめた。
- 現状: `packages/rift.nix`、`modules/rift/files/config.toml`（`settings.layout.scrolling.gestures` は無効、`settings.gestures` は有効）。
- 版を上げるときは、scrolling layout の上で三本指の切替を実機で確かめる。

## OmniWM

- 他の window manager とは同時に動かない。rice を切り替えるときは、旧 launchd agent を bootout してから残ったプロセスを止める（`modules/omniwm/default.nix`）。
- Home Manager の settings では設定を管理しない。force 付きのテンプレートが次の switch で GUI の変更を上書きし、OmniWM は完全な schema を要求するので部分的な TOML も置けない。代わりに、OmniWM が作った schema 5 の設定を入力にして、Rift 風の操作とアプリの割当だけを1回、バックアップ付きで適用する（`modules/omniwm/files/apply-rift-preset.py`、`modules/omniwm/files/rift-preset.json`）。適用済みの印は、設定ファイルの隣の `.rift-preset-applied`。
- 0.8.0 は初回起動時に設定を schema 4 から 5 へ一方向に書き換え、`settings.toml.pre-v5` を残す。0.7.6 は schema 5 を読めないので、版を戻すときはこのバックアップを戻す。版を上げるときは、プリセットの action ID と schema 判定を新しい版の `SettingsTOMLMigration.swift` に合わせる。
- darwin-installers は起動中のアプリを上書きしないので、版を上げる switch の前に OmniWM を正常終了する。正常終了では launchd が再起動しないため、switch 後に `launchctl kickstart gui/$(id -u)/org.nix-community.home.omniwm` で起動する。
- 画面収録の権限と Raycast からの発見のため、Nix store への symlink ではなく `/Applications/OmniWM.app` に通常配置する（`modules/darwin-installers/files/apps.json`、`packages/omniwm.nix`）。
- OmniWM の rice では SketchyBar と JankyBorders を無効にし、内蔵の workspace bar と枠線を使う（`rices/darwin/omniwm.nix`）。0.8.0 からバーは OmniShell のスタイルが描き、スタイルの値が `[workspaceBar]` より優先される。既定のスタイルは幅いっぱいでメニューバーに重なり、macOS のメニューバー自動非表示を「常に」にするので、見た目は Settings > Styles & Widgets で整える。
- 配色は OmniWM の App Theming に任せる。経緯と一度だけの設定は [macos-wallpaper-theming.md](./macos-wallpaper-theming.md)。
- Rift 固有のレイアウトや任意コマンドの起動は、別のキーボード daemon で真似しない。
