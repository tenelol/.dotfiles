# 壁紙からの配色（OmniWM App Theming）

OmniWM の rice では、Ghostty・Neovim・herdr の色を OmniWM のパレット（既定は壁紙から作る Material 3 配色）に追従させる。end-4 の dots-hyprland のような matugen とテンプレートの仕組みは自作せず、OmniWM 内蔵の機能に任せる。

## 経緯・判断・理由

- OmniWM には壁紙パレット（v0.8.0 以降、`theme = "wallpaper"`）と、そのパレットを他アプリへ書き出して再読み込みさせる App Theming がある。App Theming は 2026-11-13 に `main` へ入った（OmniNull/OmniWM PR #1207）。v0.8.0 と `canary-20261113-0413` には含まれないので、それより新しい canary か次のリリースが要る。
- 自作すると壁紙変更の検知・ライト/ダークの切替・各アプリの再読み込みを自分で保守することになり、内蔵機能と役割が重なるので見送った。
- OmniWM は書き込み先を home の中に限り、Nix store への symlink には書かない。そこで `myconfig.theme.colors = "omniwm"`（`rices/darwin/omniwm.nix`）のときだけ、該当ファイルを通常ファイルにしている。
- App Theming の有効化は `~/.config/omniwm/settings.toml` に入る。このファイルは GUI の変更を保つ方針（[macos-window-managers.md](./macos-window-managers.md)）なので、Nix からは書かず、下の手順を一度だけ GUI で行う。

## 現状

| 対象 | 仕組み | 実装 |
| --- | --- | --- |
| Ghostty | 設定から色の行を外し `theme = light:omniwm-light,dark:omniwm-dark` を参照する。OmniWM が `~/.config/ghostty/themes/omniwm-{light,dark}` を書いて `SIGUSR2` で再読み込みする。有効化までは Glacier の色を同じ名前で置いておく（無ければ作るだけで、上書きはしない）。 | `modules/ghostty/default.nix` |
| herdr | `config.toml` を通常ファイルで置き、switch のたびに `[theme.custom]` 以外をリポジトリの内容へ戻す。OmniWM はその表だけを書き換える。 | `modules/herdr/files/sync-config.py` |
| Neovim | OmniWM のカスタムテンプレートが `~/.config/theme/omniwm-palette` に役割ごとの色を書き、`core.theme` がそれを Glacier のキーへ割り当てる。動作中の Neovim はフォルダを監視して colorscheme を引き直す。 | `modules/omniwm/files/app-themes/nvim-palette`、`modules/nvim/files/lua/core/wallpaper-palette.lua` |
| tmux・シェーダー | ANSI 色（`iPalette[4]` など）を使うので Ghostty に付いてくる。 | 変更なし |
| OmniWM のバー | 壁紙パレットを選べばそのまま追従する。 | OmniWM 側 |

- Neovim に OmniWM 内蔵の Neovim 項目は使わない。あれは base16-nvim で colorscheme ごと置き換えるので、tokyonight の上に組んだ Glacier の割り当て（`plugins/tokyonight.lua`）が消える。
- キーワードの色は `accent` ではなく ANSI 4 にした。Terminal Colors が Follow Palette のとき ANSI 2（文字列）が `accent` になり、同じ色になるため。
- フォーカス枠（`[borders]` の `color` / `darkColor`）は固定色で、パレットには連動しない。連動させるには `settings.toml` を外から書き換えるしかなく、GUI と競合するので作っていない。

## 一度だけ行う設定

1. OmniWM を App Theming 入りの版にする（Settings に App Theming のページがあれば入っている）。版は `packages/omniwm.nix` で固定しているので、対応版が出たらそこの版とハッシュを上げる。
2. パレットを壁紙にする: `omniwmctl shell theme wallpaper`（配色の作り方は `tonalSpot` が既定。`vibrant` などを後ろに付けられる）。
3. `nh darwin switch . -H macbook-omniwm` で下準備（シード、テンプレート、herdr の通常ファイル化）を入れる。
4. Settings → App Theming で次を有効にする。
   - Ghostty: 既存の `omniwm-light` / `omniwm-dark`（シード）を置き換える確認が出る。
   - herdr: `[theme.custom]` の差分の確認が出る。
   - Add Custom Template…: テンプレート `~/.config/omniwm/app-themes/nvim-palette`、出力 `~/.config/theme/omniwm-palette`、書き込み後は Do Nothing。
5. Terminal Colors は好みで選ぶ。Follow Palette は壁紙の色に寄り、赤や緑が赤・緑に見えないことがある。Standard Hues は `git diff` などの色相を保つ。

## 未確認・注意

- App Theming が未リリースの時点（2026-11-16、実機は OmniWM 0.7.6）で用意したので、OmniWM からの書き込みと再読み込みは確かめていない。確かめたのは次の範囲。
  - switch 後の下準備: Ghostty のテーマ参照とシード、herdr の通常ファイル化、テンプレートの配置。見た目は Glacier のまま。
  - herdr の表の保持（`modules/herdr/tests/test_sync_config.py`）と、パレットの読み取りと割り当て（`modules/nvim/tests/wallpaper-palette.lua`）。
  - フォルダ監視による Neovim の再適用。パレットファイルを手で差し替え、実機の Neovim で colorscheme が1回ずつ引き直されるのを見た。
- 残りは、OmniWM が書いたテーマでの Ghostty の再読み込み、OmniWM が書いた herdr の表の保持、rift へ戻したときの復帰、ライト時の見え方。
- macOS がライトのときは OmniWM がライト用の色を書く。常にダークにしたいなら Ghostty の参照を `theme = omniwm-dark` に変える。
- lualine と bufferline、ロックオンとヤンクのハイライト（`core/motion.lua` の `accent` / `flash`）は読み込み時の色を持ち続けるので、Neovim を開き直すと揃う。
- rift など他の rice へ戻すと、Ghostty・herdr・Neovim は固定の Glacier に戻る。`~/.config/ghostty/themes/omniwm-*` と `~/.config/theme/omniwm-palette` は残るが参照されない（Neovim はテンプレート `~/.config/omniwm/app-themes/nvim-palette` が配置されている rice でだけ読む）。
