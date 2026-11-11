# Project context protocol

作成済みcontextの参照・保存・docsへの移動が必要なときだけ読む。現在のrepository・docs・issue・PR・CI・runtimeで完結する作業では読み込みも初期化も不要。

## 位置づけと運用の判定

project contextは共同・業務repository（業務委託先、インターン先、法人など）向けの、公開前の下書き置き場である。確定したものだけを`$project-context-promote`でrepositoryの`docs/`等へ移す。

運用の判定は、解決した正本に`INDEX.md`があるかどうかだけで行う。

- **`INDEX.md`がある（v4）**: このprotocolに従って参照・保存する。
- **`INDEX.md`がない**: project contextは使わない。メモは`docs/`（既存の構成を優先し、なければ`docs/notes/`）へ書き、ユーザーがcommitして区切りで整理する。v3以前の正本が残っていても読み取りだけにし、新しい記録を足さない。

originのownerが本人以外のrepositoryで`INDEX.md`がない場合は、`docs/`へ書く前に`$project-context-init`での導入を提案する。ownerは提案のきっかけであり、運用の判定には使わない。未導入projectでは記録候補があっても構造を自動作成しない。構造の初期導入・修復・backup設定は`$project-context-init`が担当する。成果物の形式・保存先が明示されている場合はその指定を優先する。

## 正本の解決

- Git projectでは `git rev-parse --path-format=absolute --git-common-dir` が返すcommon directoryの `project-context/` を使う。linked worktreeでも同じ正本を共有する。
- 非Git projectでは、ユーザーが指定したproject root、または現在位置から最も近い既存project rootの `context/` を使う。rootを特定できなければ保存先を確認し、推測で別のstoreを作らない。
- project rootの `context` symlinkは人間向け入口であり、repositoryのAGENTS.mdへこの手順を複製しない。

## 読み方

1. 作業開始時に正本の `INDEX.md` だけを読む。ai_outputの記録ごとの一行要約・確認状態・移動先と、canonicalの一覧・参照元が載っている。
2. 本文は作業に関係する記録だけ開く。AI出力は `sources` の原文・資料と現在の一次情報で確認し、AI出力だけを一次情報として扱わない。
3. INDEXで足りないときだけ、解決済みのcanonicalに限定して `rg --hidden --no-ignore -n -i --glob '*.md' --glob '!README.md' -- '<topic>' '<context-root>/canonical'` で検索する。`.git`配下も対象にするため範囲を正本内に限る。

## 保存先と採用基準

再構成しにくく将来の判断に効く情報がある場合に、INDEXで既存記録との重複を確認し、由来に応じて保存する。repositoryから容易に再構成できる情報やroutine logを蓄積しない。ユーザーが保存対象・範囲を明示した場合はその指定を優先する。

プロジェクトをまたいで再利用できる本人の価値判断・選好・判断基準は `~/Documents/personal-context/README.md` の更新手順に従って保存し、project contextにはそのproject固有の適用理由・制約を残す。同じ原文は複製せず、正本を参照する。

| 保存先 | 内容 |
| --- | --- |
| `canonical/user/` | ユーザーの発言・人間が記したcontextの原文。AIが生成・言い換え・補足した本文を含めない |
| `canonical/sources/internal/` | 添付資料など、社内・チーム・本人から受け取った原資料。同じ原文を複製しない |
| `canonical/sources/external/` | Web・書籍・公式docs等の原資料・出典。著者の由来が不明な資料を人間の原文と断定しない |
| `ai_output/{facts,decisions,workflows,risks,open_questions}/` | AIによる抽出・要約・分析・risk・判断・手順。検証済み・人間承認済みもここに置く。frontmatter付きMarkdown |

- canonical直下は運用文書だけとし、発言はuser、資料はsourcesの対応directoryへ置く。発言は必要な原文だけをMarkdownで保存し、資料は元の形式を保持する。AIによる転記は可だが、誤字・表記・語順・文意を修正せず、補足や解釈を混ぜない。抜粋するなら連続した範囲をそのまま残し、選択範囲を明示する。訂正・撤回も元の原文を上書きせず、別の原文として記録する。
- 出典（会話・文書の識別子や位置）、発言者、記録日などの保存用metadataは原文本文と分離する。不明な出典・原文を推測で復元しない。READMEなどの運用文書は原文の記録ではない。
- AIがユーザーの決定を要約した文章もai_outputへ置く。frontmatterの`sources`に出典のcanonical内の原文・資料を、`status`（`unverified`・`verified`・`approved`）と任意の`status_note`に確認状態を、`summary`にINDEXの一行要約を書く。書式は正本の`ai_output/README.md`に従う。検証・承認してもcanonicalへ昇格させない。原文の由来と内容の正しさは別に判断する。
- AI生成物をroot直下に置かず、外部assetやscriptへ依存させない。root直下の`INDEX.md`は生成物であり、手で編集しない。承認済みの判断の記録と、スキル・AGENTS・hook等の規則変更は別の操作として扱う。

保存・更新・promoteの後は次を行う。

1. `project-context-init <project root> --reindex` で`INDEX.md`を再生成する。配布済みコマンドが`--reindex`を知らなければ管理元の`python3 /Users/tener/.dotfiles/modules/vault-context/files/project-context-init.py`を使う。frontmatterの不備で失敗したら記録を直して再実行する。
2. 正本の直下に`.git`があれば、正本のrepositoryだけでローカルcommitする（`git -C <context-root> add -A && git -C <context-root> commit -m '<内容>'`）。pushはユーザーが行う。
3. 正本の直下に`.git`がなければcommitせず、正本でgitコマンドも実行しない（Git projectでは本体repositoryの`.git`配下にあるため）。保存結果の報告で`project-context-init <project root> --git-backup`による導入を提案する。提案は会話ごとに一度とし、断られたら繰り返さない。

secret、credential、不要な個人情報、非公開顧客データ、会話全文の蓄積、システム・開発者prompt、raw tool output、routine log、scratchは保存しない。ユーザーの原文に含まれる未検証の主張は原文として保持できるが、検証済みの事実とは扱わない。

## docsへの移動

確定した記録は`$project-context-promote`でrepositoryの`docs/`等へ移す。差分の提示とユーザー承認を経て反映し、移した記録は本文を消して`promoted_to`だけを残す。commit・pushはユーザーが行う。

## 旧canonicalとHTML記録の扱い

v2以前のcanonicalや旧sourcesにはAIが整理した文章が含まれる。配置だけで原文と判定しない。必要な記録の由来を確認し、AIによる文章は内容を失わずai_outputの該当分類へ移す。原文を確認できない場合はその旨を示し、原文を創作しない。

v3以前のai_outputは自己完結HTMLである。initはHTML記録が残る正本をv4へ更新せず停止する。Markdownへの変換はユーザーの承認を得てから、変換前の状態を正本のrepositoryにcommitしたうえで行う。

初期化処理は旧sources directoryを内容を変えずcanonical/sourcesへ移す。両方にdirectoryがある場合は統合・上書きせず停止する。個々の記録の自動分類は行わない。配置変更時はAI出力からの参照も更新し、原資料内の相対参照は原文を改変せず出典の元の位置に基づいて解釈する。

## Legacyと障害時

common-dir/project-local contextがなく過去情報が必要な場合、旧判断の確認、中央protocolが必要な場合に限り `/Users/tener/.codex/bin/vault-context route --cwd <cwd> --json` と中央検索を使う。Notionは通常の保存先ではなく、明示された旧情報の調査・復旧時だけ参照する。

旧記録を削除せず、検証なしにproject canonicalへ昇格させない。参照不能なら必要な過去文脈への影響を示し、現在の証拠で進められる作業は続ける。

## 永続性とbackup

正本はGit projectではcommon directory、非Git projectではproject rootに置き、本体repositoryのcommit・push・clone対象外である。branch変更・linked worktree間では共有されるが、repository削除・再clone・別端末への移動では失われる。

`project-context-init <root> --git-backup --remote <url>` で正本を独立したgit repositoryにし、repositoryごとに指定したprivate remoteへpushできる。Git projectでは正本の`.git`が本体repositoryの`.git`配下にあるため、本体のstatus・worktree・cloneに影響しない。正本の中でgitを実行すると正本のrepositoryが対象になる。
