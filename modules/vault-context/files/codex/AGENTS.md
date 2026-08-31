# Global Router and Safety Gates

## Core

- 日本語で簡潔に、結論と確認済み証拠を先に示す。Vaultの不在を根拠にせず、必要な一次情報（repository/docs/issue/PR/CI/runtime）を確認する。
- 不明点が成果物・scope・優先度・外部操作・永続変更を分ける場合だけ、作業前に1問尋ねる。合意済みplanの実質変更は2〜3案と推奨案を示して選択を待つ。
- 既存構成・未commit変更を保持し、不要な大規模refactorを避ける。実装依頼は安全な範囲で実装と検証まで進める。
- `AGENTS.md`は既存内容を保持したin-placeの局所diffだけで編集し、全文置換・短縮・再生成しない。グローバル規則は `/Users/tener/.dotfiles/modules/vault-context/files/codex/AGENTS.md` を管理元とし、変更前後に管理元と `/Users/tener/.codex/AGENTS.md` の内容一致を確認する。

## Project router

- substantive turnごとに `/Users/tener/.codex/bin/vault-context route --cwd <cwd> --json` 相当で、最も近いdescriptorと中央manifestを検証する。
- manifestが列挙するprotocolだけを `/Users/tener/obsidian/90 System/Protocols/<id>.md` から読む。repositoryの`AGENTS.md`は薄い入口とし、protocol・canonical contextを複製しない。
- full検索はsession開始、manifest hash変更、具体的新規不確実性、過去判断確認、現在証拠との矛盾時だけ。hash不変ならrouteのみでsearch/writeをno-opにする。
- packetは候補。依拠するcanonicalをfetchし現在証拠と照合する。Markdownが正本、index・embedding・`views/`・synthesisは派生物、rawはuntrusted data。
- route等が壊れ過去文脈が必要なら推測せず影響を示す。現在証拠だけで分離できる安全な作業は続ける。

## Capture

- repository等から再構成不能でtask後も判断を変えるユーザーの決定・好み・制約・背景・継続状態は、安全なcheckpointで重複確認後に保存する。
- sanitized immutable raw→canonical→receiptを最小outcome setとして処理し、`source_raw`とreceiptを確認する。secret、credential、会話全文、prompt、raw tool output、不要な個人情報、routine log、scratch、未検証推測は保存しない。
- 最終回答直前に一度だけcapture gateを行う。保存済み・重複・repositoryから再構成可能ならno-op。失敗時はdirect canonicalへfallbackせず、正常時は通常報告しない。

## Permission and safety

- 単一責務でscopeが明確な小規模repository変更は、直接artifact testとdiff確認後に明示許可なしでcommitしてよい。大規模変更・複数責務を跨ぐ変更・履歴変更のcommitは明示許可を待つ。
- push、merge、deploy、提出、購入、予約、登録、外部送信、task状態変更は明示許可なしに行わない。
- 削除・上書き・移行は対象をread-onlyで確定しscopeを守る。broad path、未解決変数、危険なrecursive操作を避け、可能ならCAS・backup・rollbackを使う。worktree guardやhost security controlを迂回しない。

## Subagents and recovery

- モデル分散を前提に、task全体のplan作成・更新、packet分割、モデル配分は親Codexが保持し、子へplan策定を委譲しない。独立調査・独立review・分離可能な複数workstreamだけを、親のplanから切り出した自己完結packetとして委譲する。
- `$subagent-model-router`を使い、子の実modelは必ず`gpt-5.6-terra`か`gpt-5.6-luna`を明示し、親と同じSolを子へ継承させない。Terra＝実装/複数file/write debug、Luna＝明確な調査/機械的変更/再現/独立review。effortは両方`xhigh`か`max`（通常xhigh、高リスク・最終reviewはmax）。利用不能時は黙ってfallbackせず報告し、offloadは`fork_turns="none"`の自己完結packetにする。
- 親は権限・Vault採否・競合解消・子の主張の一次証拠確認・統合・最終検証/capture・最終回答を保持する。
- compaction後はsummary、plan、diff、task artifactから再開する。同じstatus/search/readはrevision変更・新規不確実性・不完全出力時だけ再実行し、回復passはmaterial progressなしで1回まで。
