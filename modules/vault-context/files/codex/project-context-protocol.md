# Project context protocol

過去判断の参照、永続情報の保存、context構造の修復が必要なときだけ読む。現在のrepository・docs・issue・PR・CI・runtimeで完結する作業では読み込みも初期化も不要。

## 正本の解決と検索

- Git projectでは `git rev-parse --path-format=absolute --git-common-dir` が返すcommon directoryの `project-context/` を使う。linked worktreeでも同じ正本を共有する。
- 非Git projectでは、ユーザーが指定したproject root、または現在位置から最も近い既存project rootの `context/` を使う。rootを特定できなければ保存先を確認し、推測で別のstoreを作らない。
- 参照が必要な場合に、その正本の `README.md` と、短い非機密の作業語に一致する `canonical/` の記録を読む。`.git`配下も検索できるよう、解決済みのcanonicalだけを対象に `rg --hidden --no-ignore -n -i --glob '*.md' --glob '!README.md' -- '<topic>' '<context-root>/canonical'` を使う。
- 不足する根拠だけ `sources/internal/` と `sources/external/` を分けて検索する。`ai_output/` は明示されたartifactまたはユーザー指定時だけ読む。
- 記録は現在の一次証拠と照合する。project rootの `context` symlinkは人間向け入口であり、repositoryのAGENTS.mdへこの手順を複製しない。

## 作成・修復

ユーザーが継続管理するprojectとして指定したrootで、保存または明示された初期化・修復が必要な場合に限り `project-context-init <project-root> --title <title>` を使う。command未導入時は `python3 /Users/tener/.dotfiles/modules/vault-context/files/project-context-init.py` を使う。

構造は `project-context/v2` を維持する。一時checkoutや使い捨てdirectoryへ作らず、独自の責務directoryを追加しない。既知の旧テンプレートだけ更新し、独自編集・既存記録は保持する。別projectを一括修復しない。

## 保存先と採用基準

保存候補がある場合だけ既存記録を検索する。repositoryから安価に再構成できる情報、重複、routine logは保存しない。

| 保存先 | 内容 |
| --- | --- |
| `canonical/{facts,decisions,workflows,risks,open_questions}/` | 人間の決定、または一次証拠で検証した永続情報。一件一責務のMarkdown |
| `sources/internal/` | 社内・チーム・本人由来の原資料。必要で安全なものだけ |
| `sources/external/` | Web・書籍・公式docs等の出典と必要な短い記録 |
| `ai_output/{facts,decisions,workflows,risks,open_questions}/` | 必要なAI下書き・要約・分析。一件一責務の静的な自己完結HTML |

AI生成物をroot直下に置かず、外部assetやscriptへ依存させず、canonicalへ自動昇格させない。承認済みの判断の保存と、スキル・AGENTS・hook等の規則変更は別の操作として扱う。

secret、credential、会話全文、prompt、raw tool output、不要な個人情報、非公開顧客データ、routine log、scratch、未検証の主張をcanonicalへ保存しない。

## Legacyと障害時

common-dir/project-local contextがなく過去情報が必要な場合、旧判断の確認、中央protocolが必要な場合に限り `/Users/tener/.codex/bin/vault-context route --cwd <cwd> --json` と中央検索を使う。NotionやpersonalDevRagは通常の保存先ではなく、明示された旧情報の調査・復旧時だけ参照する。

旧記録を削除せず、検証なしにproject canonicalへ昇格させない。参照不能なら必要な過去文脈への影響を示し、現在の証拠で進められる作業は続ける。

## 永続性

Git projectはcommon directory、非Git projectはproject rootに置き、いずれもGit管理しない。branch変更・linked worktree間では共有されるが、repository削除・再clone・別端末への移動では失われるため、必要なbackupはGitとは別に行う。
