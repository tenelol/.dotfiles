# Neovim のパネル開閉アニメーション

2026-10-04 調査。対象は端末版 Neovim の Neo-tree と ToggleTerm。候補の公式 README・ヘルプ・実装、およびこの repository の設定と直接テストを照合した。候補プラグインの実機導入比較はしていない。

## 結論

**今回比較した候補では、両パネルの開閉を実質的に改善すると確認できる代替プラグインはなかった。** Neo-tree は Edgy が実際の窓を広げ、途中幅でもファイル名を表示する。ToggleTerm は既存の Snacks.animate を使う専用処理が、実際の terminal window を縮小・拡大してジョブと出力を保持する。[現行設定: Edgy](../../modules/nvim/files/lua/plugins/edgy.lua)、[Neo-tree](../../modules/nvim/files/lua/plugins/neotree.lua)、[ToggleTerm](../../modules/nvim/files/lua/core/terminal-animation.lua)、[直接テスト](../../modules/nvim/tests/panels.lua)。Edgy の実装も幅・高さを `nvim_win_set_*` で変えるが、terminal buffer では目標寸法を直ちに採用しており、ToggleTerm の開閉を単独で代替できない。[Edgy のアニメーション実装](https://github.com/folke/edgy.nvim/blob/main/lua/edgy/animate.lua#L45-L74)。

| 候補 | 公式に確認できる対象 | 実内容を見せたまま両パネルを開閉できるか |
| --- | --- | --- |
| [Edgy](https://github.com/folke/edgy.nvim#readme) ＋ 現行 Snacks.animate | edgebar の実窓寸法をセル単位で変更。terminal は Edgy の寸法アニメーションを省略する。[実装](https://github.com/folke/edgy.nvim/blob/main/lua/edgy/animate.lua#L45-L74) | **現行構成で可**。Neo-tree の開きは Edgy、閉じと ToggleTerm の双方向は repository 側の処理が担う。[設定](../../modules/nvim/files/lua/plugins/neotree.lua)、[テスト](../../modules/nvim/tests/panels.lua) |
| [windows.nvim](https://github.com/anuvyklack/windows.nvim#readme) | focus 時の自動幅変更、最大化・復元、均等化。既定の無視 filetype に `neo-tree` を含み、推奨設定は `winwidth`・`winminwidth`・`equalalways` に及ぶ。[公式ヘルプ](https://github.com/anuvyklack/windows.nvim/blob/main/doc/windows.txt#L36-L101) | **そのままでは不可**。パネル開閉用の機能ではなく、Neo-tree は既定で対象外。現行 Edgy の配置管理と責務が重なる。これは公式 API と現行構成からの判断。 |
| [animation.nvim](https://github.com/anuvyklack/animation.nvim#readme) | libuv timer と easing を使い、数値の進行率を callback に渡す基盤ライブラリ。[公式 README](https://github.com/anuvyklack/animation.nvim#animation-class) | **単独では不可**。窓の生成・resize・terminal job の保護は利用側が実装する。現行 Snacks.animate と同じ層の置換にとどまる。 |
| [mini.animate](https://github.com/nvim-mini/mini.nvim/blob/main/doc/mini-animate.txt#L370-L387) | 通常窓の開閉を**空の floating window**で視覚化。resize は同じ窓配置の寸法変化に作用し、開閉自体には適用しない。[公式ヘルプ](https://github.com/nvim-mini/mini.nvim/blob/main/doc/mini-animate.txt#L311-L321) | **要件には不適**。開閉表示は実際の Neo-tree／ライブ terminal 内容を運ぶ方式ではない。現行設定でも両 filetype を開閉対象から外している。[設定](../../modules/nvim/files/lua/plugins/animate.lua) |

`smear-cursor.nvim` はカーソルの残像、`cinnamon.nvim` はカーソル・窓内のスクロールを扱うため、パネルの開閉候補には含めない。[smear-cursor 公式 README](https://github.com/sphamba/smear-cursor.nvim#readme)、[cinnamon 公式 README](https://github.com/declancm/cinnamon.nvim#readme)。

## 滑らかさの上限と調整先

端末 UI の基本モデルは文字セルの grid で、通常の Neovim API による窓幅・高さも整数セルになる。従って `fps` を上げても、34 列を開く間に見せられる**異なる幅は最大 34 段階**で、ピクセル単位の境界移動にはならない。[Neovim UI protocol](https://neovim.io/doc/user/api-ui-events/#ui-protocol)、[grid cell の定義](https://neovim.io/doc/user/api-ui-events/#ui-event-grid_line)、[Edgy の整数丸め](https://github.com/folke/edgy.nvim/blob/main/lua/edgy/animate.lua#L45-L74)。Edgy は `cps / fps` ずつ寸法を進める。[同実装](https://github.com/folke/edgy.nvim/blob/main/lua/edgy/animate.lua#L45-L70)。**調整前の設定**では `fps=60` と Edgy 既定 `cps=120` で Neo-tree の 1→34 列は理論上約 275 ms、閉じは 180 ms だった。この時間は調査開始時の設定からの概算で、端末描画負荷下の実測ではない。[Edgy の既定値](https://github.com/folke/edgy.nvim/blob/main/lua/edgy/config.lua#L21-L24)。

今回、Edgy を `fps=120, cps=120`、Neo-tree の閉じを `total=280`、ToggleTerm を 1 セルあたり約 9 ms（短距離の下限 140 ms、長距離の上限 360 ms）に変更した。Neo-tree は開閉を約 280 ms に揃え、ToggleTerm は広い窓ほど描画段階を増やす。[Edgy の設定](../../modules/nvim/files/lua/plugins/edgy.lua)、[Neo-tree の設定](../../modules/nvim/files/lua/plugins/neotree.lua)、[ToggleTerm の設定](../../modules/nvim/files/lua/core/terminal-animation.lua)。Snacks は `total` と `step`、整数補間、global `fps` を公開している。[Snacks.animate 公式 API](https://github.com/folke/snacks.nvim/blob/main/docs/animate.md#L40-L81)。fps だけの増加は描画の改善を保証しない。

## 描画の確認

同じ Neovim に 140 列 × 50 行の埋め込み UI を接続し、`ext_multigrid` の `win_pos`・`win_float_pos` を `flush` ごとに記録した。表は重複を除いた寸法・位置の数と、隣り合う描画間の最大移動量。モニターの実表示フレームレートを測ったものではない。[イベント形式](https://neovim.io/doc/user/api-ui-events/#ui-multigrid)、[flush の意味](https://neovim.io/doc/user/api-ui-events/#ui-protocol)。

| 対象 | 描画位置の数（調整前 → 後） | 最大移動量（調整前 → 後） |
| --- | --- | --- |
| Neo-tree 開く | 18 → 34 | 2 → 1 セル |
| Neo-tree 閉じる | 16 → 32 | 2 → 1 セル |
| ToggleTerm 縦分割・40列 開く | 20 → 39 | 2 → 1 セル |
| ToggleTerm 縦分割・40列 閉じる | 20 → 39 | 2 → 1 セル |

横分割と floating terminal も最大 1 セル刻みで開閉し、ジョブが生存することを確認した。端末入力モードの実キー入力 `Ctrl-\` で、横・縦・floating の各ウィンドウを閉じられることも確認した。[キー設定](../../modules/nvim/files/lua/plugins/toggleterm.lua)。既存の直接テストは、途中のファイル名表示、開閉反転、サイズ復元、ジョブ・出力保持を検証し、縦分割のケースを 40 列へ広げた。[パネルの直接テスト](../../modules/nvim/tests/panels.lua)。スクロールはユーザーの希望により元の mini.animate に戻した。[スクロール設定](../../modules/nvim/files/lua/plugins/animate.lua)。switch は実行していない。

ピクセル単位の窓移動まで求める場合、[Neovide は GUI として窓位置アニメーションを提供する](https://neovide.dev/features.html#animated-windows)。[位置アニメーション時間の設定](https://neovide.dev/configuration.html#position-animation-length)もある。ただし端末版 Neovim を維持する今回の条件では採用対象外で、Neo-tree／ToggleTerm の live 内容についてこの調査では実機検証していない。
