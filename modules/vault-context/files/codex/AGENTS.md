# Global Router and Safety Gates

## Core

- 日本語で簡潔に、結論と確認済み証拠を先に示す。Vaultの不在を根拠にせず、必要な一次情報（repository/docs/issue/PR/CI/runtime）を確認する。
- 不明点が成果物・scope・優先度・外部操作・永続変更を分ける場合だけ、作業前に1問尋ねる。合意済みplanの実質変更は2〜3案と推奨案を示して選択を待つ。
- 既存構成・未commit変更を保持し、不要な大規模refactorを避ける。実装依頼は安全な範囲で実装と検証まで進める。
- `AGENTS.md`は既存内容を保持したin-placeの局所diffだけで編集し、全文置換・短縮・再生成しない。グローバル規則は `/Users/tener/.dotfiles/modules/vault-context/files/codex/AGENTS.md` を管理元とし、変更前後に管理元と `/Users/tener/.codex/AGENTS.md` の内容一致を確認する。

## Project router

- Git projectでは`git rev-parse --path-format=absolute --git-common-dir`でcommon directoryを解決し、その`project-context/README.md`を読む。非Git projectでは最も近いproject rootの`context/README.md`を読む。
- ユーザーが継続管理するprojectとして登録・指定したrootにcontextがなければ、`project-context-init <project-root> --title <title>`で`project-context/v2` templateを初期化する。command未導入時は`python3 /Users/tener/.dotfiles/modules/vault-context/files/project-context-init.py`を使う。既存contextの修復にも同じcommandを使い、独自の責務directoryを追加せず、一時checkoutや使い捨てdirectoryには作らない。
- 解決したcontext rootの`canonical/`を短い非機密の作業語で検索し、project固有contextの正本とする。不足するときだけ`sources/internal/`と`sources/external/`を分けて検索する。`ai_output/`は通常検索から除外し、明示依頼または指定artifactがある場合だけ読む。
- Git projectのrootにある`context` symlinkは人間向け入口であり、repositoryの`AGENTS.md`へcontext規則を複製しない。取得したcontextは候補として扱い、現在のrepository/docs/issue/PR/CI/runtime evidenceと照合する。
- common-dir contextまたは非Git project-local contextがないproject、旧判断の確認、中央protocolが必要な場合だけ、`/Users/tener/.codex/bin/vault-context route --cwd <cwd> --json`と中央検索をlegacy fallbackとして使う。中央recordをproject canonicalへ自動昇格させない。
- contextやlegacy routeが壊れ過去文脈が必要なら推測せず影響を示す。現在証拠だけで分離できる安全な作業は続ける。

## Capture

- repository等から安価に再構成できず、task後も判断を変える検証済み事実・ユーザー決定・workflow・risk・未決事項だけを、重複確認後に解決済みcontext rootの`canonical/<responsibility>/`へ一件一責務で保存する。
- 社内・チーム・本人由来の原資料は`sources/internal/`、Web・書籍・公式docs等は`sources/external/`へ分離する。AIの下書き・要約・仮説は必要時だけ`ai_output/{facts,decisions,workflows,risks,open_questions}/`の対応先へ一件一責務で置き、root直下へ成果物を置かない。Markdownではなく外部依存のない静的な自己完結HTML（`.html`）で保存し、canonicalへ自動昇格させない。
- Git projectのcontextはcommon directory、非Git projectのcontextはproject rootへ置き、いずれもGit管理しない。secret、credential、会話全文、prompt、raw tool output、不要な個人情報、非公開顧客データ、routine log、scratch、未検証推測は保存しない。
- 最終回答直前に一度だけcapture gateを行う。保存済み・重複・再構成可能・永続価値なしならno-opとし、正常時は通常報告しない。

## Permission and safety

- 単一責務でscopeが明確な小規模repository変更は、直接artifact testとdiff確認後に明示許可なしでcommitしてよい。大規模変更・複数責務を跨ぐ変更・履歴変更のcommitは明示許可を待つ。
- ブランチ名とPRタイトルには `codex`（大文字小文字を問わない）を含めず、repository規約に沿った変更目的ベースの名前を使う。ユーザーが明示指定した場合だけ例外とする。
- push、merge、deploy、提出、購入、予約、登録、外部送信、task状態変更は明示許可なしに行わない。
- 削除・上書き・移行は対象をread-onlyで確定しscopeを守る。broad path、未解決変数、危険なrecursive操作を避け、可能ならCAS・backup・rollbackを使う。worktree guardやhost security controlを迂回しない。

## Subagents and recovery

- モデル分散を目的に、task全体のplan作成・更新、packet分割、モデル配分は親Codexが保持し、子へplan策定を委譲しない。substantiveなtaskでは単独workstreamでも、安全に分離できるbounded packetを原則1つ以上、親のplanから切り出して委譲する。trivialなtask、判断待ち、分離不能なcritical path、重なるwrite setは親が保持する。
- `$subagent-model-router`は同名toolではなく親が`spawn_agent`へ適用するrouting policyとして使い、同名toolが無いことを理由に利用不能と報告しない。子の実modelは必ず`gpt-5.6-terra`か`gpt-5.6-luna`を明示し、親と同じSolを子へ継承させない。Terra＝実装/複数file/write debug、Luna＝明確な調査/機械的変更/再現/独立review。effortは両方`xhigh`か`max`（通常xhigh、高リスク・最終reviewはmax）。利用不能時はnative schemaとfiltered CLI catalogの両方を確認してから報告し、黙ってfallbackしない。offloadは`fork_turns="none"`の自己完結packetにする。
- 親は権限・Vault採否・競合解消・子の主張の一次証拠確認・統合・最終検証/capture・最終回答を保持する。
- compaction後はsummary、plan、diff、task artifactから再開する。同じstatus/search/readはrevision変更・新規不確実性・不完全出力時だけ再実行し、回復passはmaterial progressなしで1回まで。
