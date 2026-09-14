# Project context protocol

作成済みcontextの参照・保存が必要なときだけ読む。現在のrepository・docs・issue・PR・CI・runtimeで完結する作業では読み込みも初期化も不要。

## 初期化と日常運用

構造の初期導入・修復を依頼された場合は`$project-context-init`を使う。一度作成した構造はtask・スレッド間で再利用する。記録の参照・追加・更新は必要に応じて行い、その都度ユーザーの指示を求めない。未導入projectでは記録候補があっても構造を自動作成しない。

## 正本の解決と検索

- Git projectでは `git rev-parse --path-format=absolute --git-common-dir` が返すcommon directoryの `project-context/` を使う。linked worktreeでも同じ正本を共有する。
- 非Git projectでは、ユーザーが指定したproject root、または現在位置から最も近い既存project rootの `context/` を使う。rootを特定できなければ保存先を確認し、推測で別のstoreを作らない。
- 参照が必要な場合に、その正本の `README.md` と、短い非機密の作業語に一致する `canonical/` の記録を読む。`.git`配下も検索できるよう、解決済みのcanonicalだけを対象に `rg --hidden --no-ignore -n -i --glob '*.md' --glob '!README.md' -- '<topic>' '<context-root>/canonical'` を使う。
- ユーザーの発言は `canonical/user/`、不足する原資料は `canonical/sources/internal/` と `canonical/sources/external/` を分けて検索する。過去の分析・risk・手順が必要なら `ai_output/` の該当分類を別に検索し、出典の原文と現在の一次情報で確認する。AI出力だけを一次情報として扱わない。
- 記録は現在の一次証拠と照合する。project rootの `context` symlinkは人間向け入口であり、repositoryのAGENTS.mdへこの手順を複製しない。

## 保存先と採用基準

導入済みprojectでは、再構成しにくく将来の判断に効く情報がある場合に既存記録との重複を確認し、必要な原文・資料・AIの整理結果を由来に応じて保存する。repositoryから容易に再構成できる情報やroutine logを蓄積しない。ユーザーが保存対象・範囲を明示した場合はその指定を優先する。

| 保存先 | 内容 |
| --- | --- |
| `canonical/user/` | ユーザーの発言・人間が記したcontextの原文。AIが生成・言い換え・補足した本文を含めない |
| `canonical/sources/internal/` | 添付資料など、社内・チーム・本人から受け取った原資料。同じ原文を複製しない |
| `canonical/sources/external/` | Web・書籍・公式docs等の原資料・出典。著者の由来が不明な資料を人間の原文と断定しない |
| `ai_output/{facts,decisions,workflows,risks,open_questions}/` | AIによる抽出・要約・分析・risk・判断・手順。検証済み・人間承認済みもここに置く。静的な自己完結HTML |

- canonical直下は運用文書だけとし、発言はuser、資料はsourcesの対応directoryへ置く。発言は必要な原文だけをMarkdownで保存し、資料は元の形式を保持する。AIによる転記は可だが、誤字・表記・語順・文意を修正せず、補足や解釈を混ぜない。抜粋するなら連続した範囲をそのまま残し、選択範囲を明示する。訂正・撤回も元の原文を上書きせず、別の原文として記録する。
- 出典（会話・文書の識別子や位置）、発言者、記録日などの保存用metadataは原文本文と分離する。不明な出典・原文を推測で復元しない。READMEなどの運用文書は原文の記録ではない。
- AIがユーザーの決定を要約した文章もai_outputへ置き、出典のcanonical内の原文・資料を参照する。検証・承認の状態は出力内に記載し、canonicalへ昇格させない。原文の由来と内容の正しさは別に判断する。
- AI生成物をroot直下に置かず、外部assetやscriptへ依存させない。承認済みの判断の記録と、スキル・AGENTS・hook等の規則変更は別の操作として扱う。

secret、credential、不要な個人情報、非公開顧客データ、会話全文の蓄積、システム・開発者prompt、raw tool output、routine log、scratchは保存しない。ユーザーの原文に含まれる未検証の主張は原文として保持できるが、検証済みの事実とは扱わない。

## 旧canonicalの扱い

v2以前のcanonicalや旧sourcesにはAIが整理した文章が含まれる。配置だけで原文と判定しない。必要な記録の由来を確認し、AIによる文章は内容を失わずai_outputの該当分類へ移す。原文を確認できない場合はその旨を示し、原文を創作しない。

初期化処理は旧sources directoryを内容を変えずcanonical/sourcesへ移す。両方にdirectoryがある場合は統合・上書きせず停止する。個々の記録の自動分類は行わない。配置変更時はAI出力からの参照も更新し、原資料内の相対参照は原文を改変せず出典の元の位置に基づいて解釈する。

## Legacyと障害時

common-dir/project-local contextがなく過去情報が必要な場合、旧判断の確認、中央protocolが必要な場合に限り `/Users/tener/.codex/bin/vault-context route --cwd <cwd> --json` と中央検索を使う。NotionやpersonalDevRagは通常の保存先ではなく、明示された旧情報の調査・復旧時だけ参照する。

旧記録を削除せず、検証なしにproject canonicalへ昇格させない。参照不能なら必要な過去文脈への影響を示し、現在の証拠で進められる作業は続ける。

## 永続性

Git projectはcommon directory、非Git projectはproject rootに置き、いずれもGit管理しない。branch変更・linked worktree間では共有されるが、repository削除・再clone・別端末への移動では失われるため、必要なbackupはGitとは別に行う。
