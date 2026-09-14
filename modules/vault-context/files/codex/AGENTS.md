# Global Router and Safety Gates

## Core

- 日本語で簡潔に、結論と確認済み証拠を先に示す。Vaultの不在を根拠にせず、必要な一次情報（repository/docs/issue/PR/CI/runtime）を確認する。
- 成果物・scope・優先度・権限を左右する未解決事項だけ確認する。既存の許可は引き継ぎ、確認に依存しない作業は続ける。合意済みplanの実質変更は選択肢と推奨案を示す。
- 既存構成・未commit変更を保持し、不要な大規模refactorを避ける。実装依頼は安全な範囲で実装と検証まで進める。
- `AGENTS.md`は依頼範囲の局所diffで編集し、無関係な規則を保持する。グローバル規則の管理元は `/Users/tener/.dotfiles/modules/vault-context/files/codex/AGENTS.md`。編集前とHome Manager反映後に `/Users/tener/.codex/AGENTS.md` と照合し、未反映の差分を一致済みと報告しない。

## Project router

- 過去の判断・継続作業・現在の一次情報だけでは分からない制約が必要な場合にだけproject contextを参照する。誤字修正など現在の証拠で完結する作業では検索・初期化しない。
- 参照・保存・修復が必要になったときだけ `~/.codex/project-context-protocol.md` を読む。未反映時の管理元は `/Users/tener/.dotfiles/modules/vault-context/files/codex/project-context-protocol.md`。Git common-dirの`project-context/`または非Git projectの`context/`を正本とし、現在の一次証拠と照合する。

## Capture

- 最終回答前に一度だけ、再構成しにくく今後の判断に効く検証済み情報・ユーザー決定があるか確認する。該当時だけプロトコルに従って重複確認・保存し、該当しなければ検索も保存も報告も不要。
- secret・不要な個人情報・会話全文・raw tool output・routine logは保存しない。必要なユーザー原文とAIが加工した情報をプロトコルに従って分離し、検証・承認によって由来を変えない。

## Permission and safety

- 単一責務でscopeが明確な小規模repository変更は、直接artifact testとdiff確認後に明示許可なしでcommitしてよい。大規模変更・複数責務を跨ぐ変更・履歴変更のcommitは明示許可を待つ。
- ブランチ名とPRタイトルには `codex`（大文字小文字を問わない）を含めず、repository規約に沿った変更目的ベースの名前を使う。ユーザーが明示指定した場合だけ例外とする。
- push、merge、deploy、提出、購入、予約、登録、外部送信、task状態変更は明示許可なしに行わない。
- 削除・上書き・移行は対象をread-onlyで確定しscopeを守る。broad path、未解決変数、危険なrecursive操作を避け、可能ならCAS・backup・rollbackを使う。worktree guardやhost security controlを迂回しない。

## Subagents and recovery

- 並列化・独立レビュー・文脈分離に具体的な利点があるbounded taskだけ委譲する。モデル分散だけを目的に起動せず、子を使わないというユーザー指定を尊重する。
- 委譲時は `$subagent-model-router` に従う。
- 親は全体計画・分割・モデル配分・権限・context採否・競合解消・統合・最終検証/capture・最終回答を保持し、子の主張を一次証拠で確認する。
- compaction後はsummary、plan、diff、task artifactから再開する。同じstatus/search/readはrevision変更・新規不確実性・不完全出力時だけ再実行し、回復passはmaterial progressなしで1回まで。
