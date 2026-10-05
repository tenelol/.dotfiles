# 標準メモとローカルファイルの双方向同期

memo-syncは、Macの標準メモで選択したメモを ~/Documents/memo/ に登録する自作ツール。Neovimで通常のファイルとして編集すると標準メモへ反映し、標準メモでの変更もファイルへ反映する。このMacでは全件取り込みを有効にし、新しいメモも自動でファイル化する。書き戻せるテキストメモは双方向、添付・書式などを含むメモは標準メモからファイルへの同期にする。

## 反映と登録

denixの[memo-syncモジュール](../modules/memo-sync/default.nix)がHome Manager経由でCLI・Macのサービス・launchd agentを配置する。反映は現在のriceを確認した上でnh darwin switchを使う。agentはログイン時から5秒間隔で監視し、2回続けて変化がなかった内容を同期する。

全件取り込みは以下を実行する。「最近削除した項目」は除き、同名タイトルや既存ファイルとの衝突では別名を選ぶ。元メモの本文は変更しない。以後、監視中は30秒間隔で新しいメモを探して登録する。ロックなどで読めないメモは .memo-sync/import-errors.json に記録し、他のメモは続ける。

    memo-sync import-all

既に登録したメモのdisableは新規メモの探索で解除しない。import-allを明示的に再実行すると、既存登録も含めて同期の有効化を試みる。

個別に追加する場合は、標準メモで1件選び、「メモ → サービス → メモをローカル編集に追加」を実行する。対応するテキストメモは登録と同時に自動同期が有効になる。個別登録では、対応外のメモもファイルと原本は保存し、書き戻しは有効にしない。全件取り込みでは、対応外でもメモ側の本文変更をファイルへ反映する。ターミナルからも実行できる。

    memo-sync register --sync

既存ファイルと同名なら別名を選ぶ。同じメモの再登録ではローカルの編集内容を上書きしない。既存の登録は勝手に有効化されない。

    memo-sync enable "メモ名.md"
    memo-sync disable "メモ名.md"

registerを--syncなしで呼ぶと登録と原本保存のみ。初回のNotesへのAutomation許可は、対象を確認して許可する。DBの直接編集・フルディスクアクセス・apple-notes.nvimは使用しない。Automatorがシンボリックリンクを読めないため、workflowは通常ファイルとして管理する。

## ディレクトリとローカルからの新規作成

既定アカウント（このMacではiCloud）の標準Notesフォルダがmemo直下に対応する。memo/a/b/を作ると、標準メモにもa → bの階層を作る。空のディレクトリも対象。ここで.mdを保存すると、同じフォルダに新しいメモを作成して双方向同期を開始する。

    mkdir -p ~/Documents/memo/a
    nvim ~/Documents/memo/a/名前.md

新規ファイルの本文は先頭行がメモのタイトルになる。ファイル名は保存した名前を維持する。空ファイルは本文が入るまで待機し、自動監視では同じ内容を2回観測してから作成する。既存の標準メモに新しいフォルダやメモが追加された場合も、その階層で取り込む。既定以外のアカウントのメモは_accounts/配下に区別して取り込み、この場所からの新規作成は行わない。

現在のフォルダ対応は作成・追加のみ。移動・改名・削除は自動反映しない。登録済みフォルダの位置変更や、ローカルで移動した既存メモの候補は記録して停止し、新規メモとして複製しない。既定Notesフォルダ名・最近削除した項目・隠しディレクトリは新規作成先に使わない。

作成前にローカルの本文を履歴へ保存し、処理記録を先に残す。標準メモの作成後は本文と作成先を照合する。失敗やタイムアウト後は再作成を止め、create_interruptedとして標準メモとoperations/の記録を確認する。元のファイルは保持する。ディレクトリ・作成先のエラーは.memo-sync/directory-errors.jsonに記録する。

## 対応する内容

ファイルはAppleのplaintextを取得したUTF-8の.md。Markdown書式への変換は行わないため、記号として書いたMarkdownはそのまま本文に入る。通常の段落・空行・標準の先頭タイトルに対応し、日本語・絵文字・HTML記号・連続スペース・タブを保持する。先頭行を変えると標準メモのタイトルも変わるが、登録ファイル名は維持する。

添付・共有・表・チェックリスト・箇条書き・本文の装飾などを含むメモの書き戻しは停止する。HTMLから取得した全文がAppleのplaintextと一致することも書込前に確認する。同期中にメモ側へ対応外の書式が加わった場合、テキストの取込はできるが、次の書き戻しは停止する。空の本文も書き戻さない。

iCloudへの同期は標準メモが担当する。このツールで検証しているのはMac上の標準メモとの往復で、別端末とのiCloud往復は未検証。

## 確認と競合

    memo-sync status
    memo-sync diff "メモ名.md"
    memo-sync sync

statusとdiffは本文を更新しない。syncは有効化したメモを一度同期する。件数に応じて全件の読取時間もかかる。手動監視にはmemo-sync watchを使い、終了はCtrl+C。launchd agentと同じ保存先で同時に動かす必要はない。自動監視の確認・再起動には以下を使う。

    launchctl print gui/(id -u)/org.nix-community.home.memo-sync
    launchctl kickstart -k gui/(id -u)/org.nix-community.home.memo-sync

監視ログは ~/Library/Logs/memo-sync.log。

上のlaunchctlコマンドはFish用。Bash/Zshでは(id -u)を$(id -u)にする。

| 状態 | 意味 |
| --- | --- |
| in_sync | 最後の同期版と両側の本文が一致 |
| push_pending / pull_pending | 片側の変更。無効な登録では保留、有効な登録では次の同期対象 |
| conflict | 両側が別々に変更。どちらも更新しない |
| converged / format_changed | 同じ本文への変更・メモ側の書式変更。同期時に基準版を更新 |
| unsupported | 内容の保持を確認できず、書き戻しを停止 |
| interrupted | 同期途中の失敗。自動再試行による書き込みを停止 |
| folder_changed / create_interrupted | フォルダ位置の変更・新規作成の中断。自動更新や再作成は停止 |
| unavailable | ロック・権限などで読めない。そのメモの更新は止め、他は継続 |
| local_missing / remote_missing | 片側が見つからない。もう一方を削除しない |

競合時はmemo-sync disableでそのメモを止め、diffと履歴を確認する。必要な両側の内容を別ファイルへ保全してから、採用する本文を両側で一致させ、memo-sync enableで再開する。本文が一致しない途中失敗はenableで解除できない。force上書きコマンドは設けない。

## 履歴と更新の保護

.memo-sync/history/に各版のHTML・本文・ID・属性、local-history/に更新前のファイル、operations/に更新記録、reports/に状態と差分を保存する。最初の原本も保持し、差分の基準は成功した同期ごとに進める。添付ファイルのバイナリ本体は保存しない。

メモへの書込直前にID・本文・HTML・日時・属性を再照合し、書込後に本文が一致することを確認する。ファイル更新にはOSの原子的な交換を使い、置き換えたファイル自体も履歴に残す。交換時に編集が入っていたら-displaced.txtへ保全し、そのメモの同期を停止する。途中処理の記録を先に保存し、クラッシュ後は一致を確認できた完了分だけ基準版を進める。

AppleのスクリプトAPIには比較と書込を一体にしたトランザクションがないため、直前の照合と書込の間の同時編集までは排他できない。両側で同じメモを同時に編集する運用は避ける。履歴は自動削除しないので容量管理は手動。管理フォルダは700、本文・原本・記録は600で作成する。

## 検証

[artifact tests](../modules/memo-sync/tests/)は合成データを使い、往復・原本保存・競合・同時保存・削除・中断・本文不一致時の停止を検証する。

    python3 -m unittest discover -s modules/memo-sync/tests -p 'test_*.py'
    node modules/memo-sync/tests/test_notes_bridge.js

実機試験は明示実行のみ。以下は専用の使い捨てメモを1件作り、往復と自動監視、本文保持、古い版の書込拒否、競合時の双方保全を確認する。既存の個人メモは対象にしない。テストメモと一時workspaceは確認用に残す。

    python3 modules/memo-sync/tests/test_notes_live.py --create

未反映でもpython3 modules/memo-sync/files/memo_sync.pyから同じCLIを使える。保存先を変える場合はサブコマンドの前に--root /path/to/memoを付ける。
