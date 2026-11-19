# Global Router and Safety Gates

## Core

- 日本語で簡潔に、結論と確認済み証拠を先に示す。Vaultの不在を根拠にせず、必要な一次情報（repository/docs/issue/PR/CI/runtime）を確認する。
- 成果物・scope・優先度・権限を左右する未解決事項だけ確認する。既存の許可は引き継ぎ、確認に依存しない作業は続ける。合意済みplanの実質変更は選択肢と推奨案を示す。
- 既存構成・未commit変更を保持し、不要な大規模refactorを避ける。実装依頼は安全な範囲で実装と検証まで進める。
- `AGENTS.md`・`CLAUDE.md`は依頼範囲の局所diffで編集し、無関係な規則を保持する。グローバル規則の管理元は `/Users/tener/.dotfiles/modules/vault-context/files/` の `shared/global-rules.md`（共通）と `codex/AGENTS.md`・`claude/CLAUDE.md`（各エージェント固有）。編集前とHome Manager反映後に配布先の `~/.codex/AGENTS.md`・`~/.claude/CLAUDE.md` と照合し、未反映の差分を一致済みと報告しない。

## Project router

- 本人の経歴・活動・関心・価値観や個人的な判断が回答に影響するときは `~/Documents/personal-context/README.md` を読み、必要なmaster・雑多コンテキストと出典だけ参照する。キャリア・学習・生活の相談、本人に向けた提案や優先順位付け、本人名義・本人紹介の文章、日記の壁打ちが該当する。該当するか迷う場合も短いREADMEを入口にし、本人固有の事情で結論が変わるときだけ参照先へ進む。
- project contextは共同・業務repository向けのオプションで、運用の判定は正本（Git common-dirの`project-context/`または非Git projectの`context/`）に`INDEX.md`があるかどうかだけで行う。ある場合は作業開始時に`INDEX.md`だけを読み、本文は関係する記録だけ開いて現在の一次証拠と照合する。ない場合はproject contextを使わず、メモは`docs/`に書く。
- 保存・docsへの移動・修復・正本のバックアップのpushが必要になったとき、または`INDEX.md`のないrepositoryのoriginのownerが本人以外のときだけ `~/.codex/project-context-protocol.md` を読む。未反映時の管理元は `/Users/tener/.dotfiles/modules/vault-context/files/codex/project-context-protocol.md`。

## Capture

- 最終回答前に一度、今後の判断に効く情報を確認する。本人が明示した汎用的な価値判断・選好・判断基準は、作業中のproject contextの有無にかかわらず `~/Documents/personal-context/README.md` に従って漏れなく保存・更新する。
- プロジェクト固有の経緯・制約・判断理由は、再構成しにくく今後の判断に効くものだけ残す。`INDEX.md`のある正本へはプロトコルに従って重複確認・保存し、それ以外は`docs/`へ書く。該当情報がなければ何もしない。記録を残すためだけに正本を新規作成しない。
- secret・不要な個人情報・会話全文・raw tool output・routine logは保存しない。必要なユーザー原文とAIが加工した情報をプロトコルに従って分離し、検証・承認によって由来を変えない。

## Documentation

- READMEは入口とする。`INDEX.md`のないrepositoryでは、設計判断・手順・経緯・制約を`docs/`（既存の構成を優先し、なければ`docs/notes/`）に書いてユーザーがcommitし、区切りで整理する。`INDEX.md`のある正本では下書きをcontextに置き、確定したものだけを`$project-context-promote`で`docs/`等へ移す。
- 一つの内容に正本を一つ置き、コード・設定から読める一覧や版、検証ログの説明を重複させない。文書整理では必要な情報を適切な正本へ残してから古い場所を削り、参照を確認する。

## Browser

- ページの閲覧・操作・フォーム入力・スクリーンショット・抽出・Webアプリ確認などブラウザーを使う作業は、`phi-browser`スキルでPhi Browserを使う。組み込みブラウザー・Claude in Chrome・Playwright等は、ユーザーが名指ししたときか、Phiに接続できずユーザーが代替を了承したときだけ使う。

## Permission and safety

- 単一責務でscopeが明確な小規模repository変更は、直接artifact testとdiff確認後に明示許可なしでcommitしてよい。大規模変更・複数責務を跨ぐ変更・履歴変更のcommitは明示許可を待つ。
- push、merge、deploy、提出、購入、予約、登録、外部送信、task状態変更は明示許可なしに行わない。
- 削除・上書き・移行は対象をread-onlyで確定しscopeを守る。broad path、未解決変数、危険なrecursive操作を避け、可能ならCAS・backup・rollbackを使う。worktree guardやhost security controlを迂回しない。

## Subagents and recovery

- 並列化・独立レビュー・文脈分離に具体的な利点があるbounded taskだけ委譲する。モデル分散だけを目的に起動せず、子を使わないというユーザー指定を尊重する。
- 親は全体計画・分割・モデル配分・権限・context採否・競合解消・統合・最終検証/capture・最終回答を保持し、子の主張を一次証拠で確認する。
- compaction後はsummary、plan、diff、task artifactから再開する。同じstatus/search/readはrevision変更・新規不確実性・不完全出力時だけ再実行し、回復passはmaterial progressなしで1回まで。
