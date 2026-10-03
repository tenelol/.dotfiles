# Rift の scrolling layout と三本指 workspace swipe

2026-10-04 調査。対象は公式タグ v0.5.8.1、v0.6.0、v0.6.3、v0.6.4 のソースとリリース。後続版 v0.6.4 の公式配布済みバイナリを実機でも確認した。

## 結論

v0.6.0 が、scrolling layout で「scroll gesture 無効なら通常の workspace swipe を使う」という動作を廃止した証拠はない。**v0.5.8.1 にも同じ振り分けがあり、scrolling layout では scroll handler だけを選んでいた**。両タグの実装では、scroll handler を無効にすると通常の workspace swipe へフォールバックしない。[v0.5.8.1 `gesture_tap.rs`](https://github.com/acsandmann/rift/blob/v0.5.8.1/src/actor/gesture_tap.rs#L416-L465)、[v0.6.0 `input.rs`](https://github.com/acsandmann/rift/blob/v0.6.0/src/actor/input.rs#L1619-L1690)。従って旧 Homebrew 環境で「scrolling layout のまま、scroll gesture 無効、三本指で直接 workspace 切替」が動いていたという実機報告は、確認した二版のソースだけでは説明できない。旧プロセスの実行ファイル、実効設定、実効 workspace layout、別の gesture 処理を read-only で照合する必要がある。後者は未確認の可能性であり、原因の断定ではない。

公式の [v0.6.0 リリースノート](https://github.com/acsandmann/rift/releases/tag/v0.6.0)は今回の gesture 意味変更を挙げていない。開発者の [PR #446](https://github.com/acsandmann/rift/pull/446) は低レベル gesture 処理の CPU 負荷削減、palm rejection、アプリへの swipe 伝播抑止を動機としているが、2026-08-17 にマージされ、v0.5.8.1 より前の変更である。[PR #544](https://github.com/acsandmann/rift/pull/544) の「連続 scrolling と snapping、niri に近い操作」は [v0.6.3 リリース](https://github.com/acsandmann/rift/releases/tag/v0.6.3)で導入されたため、v0.6.0 の振る舞いの根拠にはならない。v0.6.0 の逆方向の workspace 伝播について、これを意図したという明示的な開発者説明は確認できなかった。

## v0.6.0 で観測された三つの現象

1. `settings.layout.scrolling.gestures.enabled = true` なら、scrolling layout の三本指は通常の workspace swipe より scroll gesture に優先的に渡る。指の移動はまず `ScrollStrip { delta }` になり、境界を超え、さらに `workspace_switch_threshold` に達した場合だけ workspace command になる。[振り分けと入力](https://github.com/acsandmann/rift/blob/v0.6.0/src/actor/input.rs#L1619-L1690)、[scroll delta](https://github.com/acsandmann/rift/blob/v0.6.0/src/actor/input.rs#L1828-L1847)、[境界判定](https://github.com/acsandmann/rift/blob/v0.6.0/src/layout_engine/systems/scrolling.rs#L435-L493)、[workspace への伝播](https://github.com/acsandmann/rift/blob/v0.6.0/src/actor/reactor.rs#L4420-L4450)。[公式 Config wiki](https://github.com/acsandmann/rift/wiki/Config#settingslayoutscrollinggestures)も scrolling gesture と workspace swipe を別機能として説明する。
2. 空 workspace では scrolling strip に列がなく、`scroll_by_delta` が `None` を返す。このため境界通知が発生せず、`propagate_to_workspace_swipe = true` でも workspace を切り替えられない。[v0.6.0 `scrolling.rs`](https://github.com/acsandmann/rift/blob/v0.6.0/src/layout_engine/systems/scrolling.rs#L435-L451)。`skip_empty = false` は行き先を飛ばすかに関わる設定で、この始点での早期 return は解消しない。[通常 swipe の設定生成](https://github.com/acsandmann/rift/blob/v0.6.0/src/actor/input.rs#L1455-L1472)、[伝播時の設定](https://github.com/acsandmann/rift/blob/v0.6.0/src/actor/reactor.rs#L4422-L4450)。
3. workspace 方向は直接 swipe と scrolling の境界伝播で反対になる。`invert_horizontal_swipe = false` の直接 swipe は物理的な左向き `dx < 0` を `NextWorkspace` にする。[通常 swipe](https://github.com/acsandmann/rift/blob/v0.6.0/src/actor/input.rs#L1726-L1746)。一方 `invert_horizontal = false` の scrolling は左向き `dx < 0` を左境界 `Direction::Left` にし、そこから `PrevWorkspace` にする。[scroll 入力](https://github.com/acsandmann/rift/blob/v0.6.0/src/actor/input.rs#L1832-L1846)、[境界方向](https://github.com/acsandmann/rift/blob/v0.6.0/src/layout_engine/systems/scrolling.rs#L451-L487)、[workspace 対応](https://github.com/acsandmann/rift/blob/v0.6.0/src/actor/reactor.rs#L4422-L4450)。`invert_horizontal = true` にすると scroll delta と境界→workspace の対応を両方反転させるので、物理的な左向き swipe はやはり `PrevWorkspace` になる。つまりこの設定値だけでは旧い直接 swipe の方向へ戻せない。`workspace_switch_threshold` を下げても方向は変わらない。

## 既存の公式バイナリで試せる選択肢

[v0.6.3 の公式ソース](https://github.com/acsandmann/rift/blob/v0.6.3/src/actor/gesture.rs#L50-L89)以降は、scrolling layout に合う scroll action がなければ同じ本数の通常 workspace action にフォールバックする。従って `scrolling.gestures.enabled = false` と `gestures.enabled = true`、両方 `fingers = 3` の組合せで、公式バイナリのまま直接 workspace swipe に戻せる。これは v0.6.0 に対して用意された局所 patch と同じ目的を、後続版で実現する経路である。公式 [v0.6.3](https://github.com/acsandmann/rift/releases/tag/v0.6.3) と [v0.6.4](https://github.com/acsandmann/rift/releases/tag/v0.6.4) に macOS universal のリリースアーカイブがあり、v0.6.4は下記のとおり起動・権限・実操作まで確認した。

scroll gesture を有効にしたままの場合、後続版も scrolling action を優先する。[v0.6.4 の action 選択](https://github.com/acsandmann/rift/blob/v0.6.4/src/actor/gesture.rs#L85-L89)。その経路の開始条件は selected window と geometry を要求するので、空 workspace の直接 swipe 代替にはならない。[v0.6.4 の viewport 開始条件](https://github.com/acsandmann/rift/blob/v0.6.4/src/layout_engine/systems/scrolling.rs#L1233-L1257)。

## 実機での採用結果

公式 v0.6.4 の universal archiveをGitHub release assetのSHA256 `c0e25bec6701c896751af64a787ddfefd8746ca95780b33cf86b0894f3423b94` と照合して取り込んだ。ソースコンパイルは行っていない。`settings.layout.scrolling.gestures.enabled = false` と `settings.gestures.enabled = true`、`fingers = 3` を使い、アクセシビリティ許可後に、ウィンドウ上と空のworkspaceの両方で直接切替できることをユーザーが確認した。`invert_horizontal_swipe = false` の左向きは次workspace、右向きは前workspaceとなる。Apple Musicはworkspace 6（内部index 5）へ設定し、実際の配置も確認した。

入力監視は原因切り分けの候補だったが追加しなかった。CGEventの受信経路のread-only計測では三本指のraw frameが届いており、最終的にはジェスチャーのroutingを持つ公式バイナリと設定の組合せで復旧した。用意したv0.6.0用の独自patchは採用せず削除した。
