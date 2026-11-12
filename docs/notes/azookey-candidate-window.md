# azooKey 候補ウィンドウの描画遅れ

パッチ版 azooKey で候補の選択ハイライトが1つ前の位置に残る症状は、座標ではなく Core Animation のトランザクションが未確定なことが原因だった。ConverterServer の応答を反映したあとに `CATransaction.flush()` を呼んで直した（`ccaca59`）。

## 経緯・判断・理由

- 症状: ハイライトが実際の選択より1行上に残り、Shift や Control を押すと正しい位置へ戻る。
- os_log で行ビューの座標、`rect(ofRow:)`、選択位置を照合したが、不一致は一度も記録されなかった。ConverterServer の XPC 応答はキーイベントの外で main actor に届くため、暗黙のトランザクションが次のイベントまで画面に出ない。
- レイアウトの確定、行ビューの座標の変更、次の run loop での再配置は効かなかったので取り消した。
- 以前の「Enter の直後にロックオンされない」も同じ型の症状だった。

## 現状

- 修正: `packages/azookey-desktop/effect-themes.patch` の、応答を反映したあとの flush。
- 計測: 同じパッチが subsystem `dev.ensan.inputmethod.azooKeyMac`、category `latency` に、合計 150ms を超えたキーイベントの内訳を出す（`ed55a9f`）。候補ウィンドウの調査用のログは category `candidate`。

## 再発時の手がかり

- IMK のプロセスで、応答を起点にした描画が遅れて見えるときは、座標計算より先にトランザクションの未確定を疑う。
- ログは `/usr/bin/log show` で読む。エージェントの Bash ツールの zsh では `log` が組み込みコマンドになるため、フルパスで呼ぶ。
- 打鍵後の演出で、入力先アプリへのカーソル位置の問い合わせ（同期 IPC）が1回で最大3秒かかることがあった。入力の開始時に1回だけ聞いて確定まで使い回すようにした（`2f5c1c7`）。遅さが戻ったら、latency のログの `caret` を見る。
