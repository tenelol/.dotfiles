# Neovim のファイル picker 演出と追加プラグイン

2026-10-05 調査。対象は現在の `<C-p>`（project root で `Telescope find_files`、上部 prompt、横配置、幅 0.92・高さ 0.88・preview 幅 0.55）。Telescope／Neovim／候補プラグインの公式資料と repository の設定を照合した。候補プラグインの導入・実機比較はしていない。[現行 Telescope 設定](../../modules/nvim/files/lua/plugins/telescope.lua)、[プラグイン一覧](../../packages/nvim-runtime.nix)。

## picker のアニメーション

**実内容を動かす余地はあるが、公式の layout 設定に picker 全体の開閉アニメーション項目は見当たらない。** `attach_mappings` は picker ごとに指定でき、callback 内で `action_state.get_current_picker(prompt_bufnr)` を使える。現行実装では callback は layout の `mount` と prompt／results／preview の窓 ID 設定後に呼ばれる。一方、最初の finder 処理より前なので、この時点で候補や preview の内容が揃う保証はない。[Telescope ヘルプ: `attach_mappings`](https://github.com/nvim-telescope/telescope.nvim/blob/40aedd8a68c78a656a10a8d62d80c54af59420fb/doc/telescope.txt#L1756-L1771)、[picker 取得 API](https://github.com/nvim-telescope/telescope.nvim/blob/40aedd8a68c78a656a10a8d62d80c54af59420fb/lua/telescope/actions/state.lua#L23-L28)、[picker の生成順](https://github.com/nvim-telescope/telescope.nvim/blob/40aedd8a68c78a656a10a8d62d80c54af59420fb/lua/telescope/pickers.lua#L539-L555)、[status 登録から finder 開始まで](https://github.com/nvim-telescope/telescope.nvim/blob/40aedd8a68c78a656a10a8d62d80c54af59420fb/lua/telescope/pickers.lua#L719-L743)。

Neovim の `nvim_win_get_config`／`nvim_win_set_config` は浮動窓の位置・寸法を変更できる。ただし Telescope の prompt、候補、preview と各枠は別窓なので、実内容と枠を一緒に動かす必要がある。リサイズなどで Telescope の `layout:update()` が再配置し、途中位置を上書きする可能性もある。[Neovim floating windows API](https://neovim.io/doc/user/api/#api-floatwin)、[Telescope の窓作成と update](https://github.com/nvim-telescope/telescope.nvim/blob/40aedd8a68c78a656a10a8d62d80c54af59420fb/lua/telescope/pickers.lua#L63-L211)。配置の lifecycle を全面的に扱うなら、公式の `create_layout` 拡張点には `mount`／`unmount`／`update` があるが、既定 layout の再実装量が増える。[Telescope layout ヘルプ](https://github.com/nvim-telescope/telescope.nvim/blob/40aedd8a68c78a656a10a8d62d80c54af59420fb/doc/telescope.txt#L1775-L1891)。

閉じる経路にも注意が要る。`actions.close` は `on_close_prompt` を直ちに呼び、通常は窓を破棄する。prompt から離れたときや別 picker を開いたときも閉じるため、`<Esc>` だけの差し替えでは閉じる演出を統一できない。[close action](https://github.com/nvim-telescope/telescope.nvim/blob/40aedd8a68c78a656a10a8d62d80c54af59420fb/lua/telescope/actions/init.lua#L373-L386)、[BufLeave と close 処理](https://github.com/nvim-telescope/telescope.nvim/blob/40aedd8a68c78a656a10a8d62d80c54af59420fb/lua/telescope/pickers.lua#L699-L709)、[別 picker の起動](https://github.com/nvim-telescope/telescope.nvim/blob/40aedd8a68c78a656a10a8d62d80c54af59420fb/lua/telescope/pickers.lua#L1356-L1361)。採用するならまず `<C-p>` の開く演出を小さく実装し、候補表示後の描画、枠との同期、resize／早期終了を直接確認するのが妥当。`mini.animate` の通常窓 open／close は既存設定にあるが、Telescope の浮動窓一式を実内容ごと運ぶ専用機能ではない。[現行 mini.animate 設定](../../modules/nvim/files/lua/plugins/animate.lua)。

今回の実装では、project root のファイル検索から `attach_mappings` に接続した。prompt・結果・preview と各枠を最大 2 行下から一緒に動かし、180 ms で薄い透過を元に戻す。下に余白のない画面は位置を動かさず透過だけを変える。窓が閉じたり layout が再配置されたりしたら、残りのアニメーションを止める。[設定](../../modules/nvim/files/lua/plugins/telescope.lua)、[描画処理](../../modules/nvim/files/lua/core/telescope-animation.lua)。

埋め込み UI の 140 列 × 50 行で `<C-p>` を実際に入力したテストでは、6 個の内容・枠窓が最初から揃って表示され、同じ距離を動き、透過が元に戻った。動作中に入力した検索語、ファイル名、preview も残り、Enter で目的のファイルを開けた。すぐ閉じる操作、80 列 × 24 行、動作中の resize では窓や透過が残らないことを確認した。[直接テスト](../../modules/nvim/tests/telescope.py)。実際の terminal／モニターの表示フレームレートを測るものではない。検索候補自体は Telescope の finder が非同期に描くので、最初の候補が現れる時刻はデータ量によって変わる。[Telescope の初回 finder 処理](https://github.com/nvim-telescope/telescope.nvim/blob/40aedd8a68c78a656a10a8d62d80c54af59420fb/lua/telescope/pickers.lua#L740-L743)。

## 追加候補

| 候補 | 現行構成での価値と条件 | アニメーションか |
| --- | --- | --- |
| [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim#readme) | **第一候補。** Markdown の見出し・表・コード等を編集中の buffer 内で描画し、mode に応じた raw 表示と toggle がある。現行構成には Tree-sitter の `markdown`／`markdown_inline` と `nvim-web-devicons` があり、ブラウザを開く `markdown-preview.nvim` と用途が分かれる。[parser](../../packages/nvim-runtime.nix)、[既存 preview](../../modules/nvim/files/lua/plugins/markdown-preview.lua)。視覚効果が強いので導入時は控えめな色・装飾を選ぶ。 | **なし**。表示装飾。 |
| [nvim-ufo](https://github.com/kevinhwang91/nvim-ufo#readme) | **折り畳みを常用するなら候補。** LSP／Tree-sitter／indent を fold provider に使い、折り畳み行の表示と内容 peek ができる。`promise-async` の追加、fold options・`zR`／`zM` の設定、LSP の foldingRange capability 確認が必要。現在の [LSP 設定](../../modules/nvim/files/lua/plugins/language-server.lua)にはその明示設定がない。 | **なし**。fold を開いた際の一時 highlight は設定できるが、滑らかな窓アニメーションではない。 |
| [nvim-bqf](https://github.com/kevinhwang91/nvim-bqf#readme) | **native quickfix をよく使う場合のみ。** qf 窓内 preview、選択項目の絞り込み、fzf 連携がある。現行の [Trouble qflist](../../modules/nvim/files/lua/plugins/trouble.lua) と閲覧用途が重なるので優先度は低い。 | **なし**。quickfix の操作改善。 |
| [satellite.nvim](https://github.com/lewis6991/satellite.nvim#readme) | 診断・検索結果・Git hunk 等を scrollbar に重ねられるが、公式 README は **Neovim nightly 要件**と API 不足に由来する workaround を明記する。現行ホストの Neovim 版・描画負荷を確かめるまでは保留。 | **なし**。装飾 scrollbar。 |

追加導入の候補は `render-markdown.nvim`。折り畳みを頻繁に使うなら `nvim-ufo` も候補になる。両者は `<C-p>` の開閉演出を直接解決するプラグインではない。
