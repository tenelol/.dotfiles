# コンテキスト構造・引き継ぎ資料

確認日: 2026-11-11

対象: このdotfilesで管理するCodex・Claude Code・Pi共通のプロジェクトコンテキスト（`project-context/v4`）

この環境では、**全体の運用ルールはdotfilesで管理し、共同・業務リポジトリの公開前の下書きだけを各プロジェクトのローカル領域に置く**。個人リポジトリではプロジェクトコンテキストを使わず、メモを `docs/` に書いてコミットする。共同リポジトリでも確定したものは `docs/` などへ移し、ローカルには下書きと共有しない原文・資料だけを残す。

本書は構造を第三者に説明するための資料であり、個別プロジェクトの記録や会話内容のエクスポートではない。運用ルールの正本は後述の管理元ファイルにある。パスの `~` は利用者のホームディレクトリを表す。

## 1. 全体の構成

| 構成要素 | 役割 | 主な配置 |
| --- | --- | --- |
| エージェント共通ルール | いつ過去の文脈を読むか、保存条件、作業権限を定める | Codex: `~/.codex/AGENTS.md`、Claude Code: `~/.claude/CLAUDE.md`（どちらも共通ルール＋固有部）、Pi: `~/.pi/agent/AGENTS.md` |
| 共有プロトコル | 正本の探し方、原文とAI出力の分離、検索・保存・旧記録の扱いを定める | 各エージェントの `project-context-protocol.md` |
| プロジェクト固有ルール | そのリポジトリの構成・検証・コミット方針など | プロジェクトの `AGENTS.md` |
| プロジェクトコンテキスト | タスクをまたいで残す原文・原資料・AIによる分析 | Git共通ディレクトリの `project-context/`、または非Gitプロジェクトの `context/` |
| 初期化用スキル・コマンド | コンテキストの初期導入、構造修復、INDEX再生成、バックアップ設定 | `project-context-init` |
| 移動用スキル | 確定したAI出力を `docs/` などへ移す。未確認の記録の照合も手伝う | `project-context-promote` |
| 旧Vault連携 | 旧判断の確認・復旧など、必要な場合だけ使う補助経路 | Obsidian Vault、`vault-context` CLI・MCP |

日常作業で確認する一次情報は、現在のリポジトリ、公式文書、Issue、PR、CI、実行結果など。保存された過去の記録も、必要に応じて現在の一次情報と照合する。

CodexとClaude Codeは共通ルールに各エージェント固有の記述を足したものを使い、Piは独自のルールを持つ。コンテキストのプロトコルは同じ管理元を使う。同じGitリポジトリを扱う場合、保存先も同じGit共通ディレクトリに解決される。この共有はローカルのClaude Codeが対象で、Claudeの通常チャットやCoworkの設定とは別になる。

## 2. 保存先とディレクトリ構造

### Gitプロジェクト

正本は次のコマンドで得たGit共通ディレクトリの `project-context/`。通常のチェックアウトでは `.git/project-context/` になるが、linked worktreeでは `.git` がファイルの場合もあるため、固定パスで推測しない。

```sh
git rev-parse --path-format=absolute --git-common-dir
```

```text
project/
├── AGENTS.md                     プロジェクト固有ルール（Git管理）
├── context -> <common-dir>/project-context/
└── ...                           ソースコードなど

<common-dir>/project-context/      コンテキストの正本（本体リポジトリのGit管理外）
├── .git/                         任意。--git-backup で作る正本専用のリポジトリ
├── README.md                     この保存先の運用説明
├── INDEX.md                      記録の一覧（生成物）。v4運用の目印
├── canonical/
│   ├── README.md                 原文・原資料の保存ルール
│   ├── user/                     ユーザーの発言・人間が記した原文
│   └── sources/
│       ├── internal/             本人・チームなどから受け取った原資料
│       │   └── README.md
│       └── external/             公式文書・Web・書籍などの原資料・出典
│           └── README.md
└── ai_output/
    ├── README.md                 AI出力の保存ルールとfrontmatterの書式
    ├── facts/                    AIが抽出・整理した事実
    ├── decisions/                AIが整理した判断・理由
    ├── workflows/                AIが整理した手順
    ├── risks/                    AIが整理したリスク
    └── open_questions/           AIが整理した未決事項
```

`context` は人間向けの入口となるシンボリックリンク。正本ではない。初期化処理はGitのローカルexcludeへ `/context` を追加する。保存先はブランチ変更やlinked worktree間で共有され、コンテキスト全体がcommit・push・cloneの対象外となる。

運用の判定は正本に `INDEX.md` があるかどうかだけで行う。このdotfilesは個人リポジトリなので、`~/.dotfiles/.git/project-context/` にあるv3の正本は、`docs/` へ移すまで読み取り専用の旧記録として扱う。

### 非Gitプロジェクト

プロジェクトルートの `context/` 自体を正本とし、中身は上記と同じ構造にする。初期化処理はプロジェクトの `AGENTS.md` に管理対象の案内ブロックを置く。Gitプロジェクトでは、中央プロトコルの手順をプロジェクトの `AGENTS.md` に複製しない。

## 3. 情報の分け方

分類の基準は**誰が作った情報か**であり、承認の有無ではない。`canonical` にある原文も、主張の正しさまで保証するものではない。

| 保存先 | 保存するもの | 形式・扱い |
| --- | --- | --- |
| `canonical/user/` | ユーザーの発言、人間が書いたコンテキストの必要な原文 | Markdown。言い換え・補足・誤字修正をしない |
| `canonical/sources/internal/` | 本人・社内・チームから受け取った添付資料など | 必要な資料を元の形式で保持 |
| `canonical/sources/external/` | 公式文書、Web、論文、書籍などの原資料・出典 | 保持が必要かつ許される範囲。著者の由来が不明なら人間の原文と断定しない |
| `ai_output/<分類>/` | AIの抽出、要約、分析、提案、検証結果 | frontmatter付きMarkdown。`title`・`summary`・`created`・`sources`・`status`・`promoted_to` を持つ |

例えば「ユーザーが運用方針を決めた発言」は `canonical/user/` に原文で置き、「その決定の理由をAIが整理した文章」は `ai_output/decisions/` に置く。AIによる整理結果を人間が承認しても、その文章を `canonical` へ移さない。

原文の出典、発言者、記録日、抜粋範囲などのメタデータは本文と分離する。抜粋は連続した範囲をそのまま残す。訂正や撤回は元の原文を上書きせず、別の原文として記録する。AI出力のfrontmatterには、原文・原資料への参照（`sources`）、確認状態（`status`: `unverified`・`verified`・`approved`）、移動先（`promoted_to`）を書く。`INDEX.md` はこのfrontmatterとcanonicalの一覧から `project-context-init --reindex` で機械的に作り、手で編集しない。

`canonical` 直下は運用文書だけにし、同じ原文を複数箇所に複製しない。READMEなどの運用文書は、人間の発言の記録とは区別する。

## 4. 普段の参照・保存の流れ

1. 正本を解決し、`INDEX.md` があるか確認する。なければプロジェクトコンテキストを使わず、メモは `docs/` に書く。originのownerが本人以外なら、導入を提案する。
2. `INDEX.md` がある場合は、作業開始時にそれだけを読み、本文は関係する記録だけ開く。AI出力は `sources` の原文と現在の一次情報で確認する。
3. INDEXで足りないときだけ、`canonical/` を短い非機密の作業語で検索する。
4. 最終回答前に一度、後から再構成しにくく今後の判断に効く情報があるか確認する。該当する情報だけ、重複を確認して由来に応じた場所へ保存し、`--reindex` でINDEXを作り直す。正本に `.git` があれば正本のリポジトリだけでローカルコミットする。pushはユーザーが行う。
5. 確定した記録は `project-context-promote` で `docs/` などへの差分を示し、ユーザーが承認したものだけ反映する。移した記録は本文を消して `promoted_to` だけを残す。本体リポジトリのコミット・pushはユーザーが行う。

Gitの隠しディレクトリとignore対象も検索するため、検索範囲を解決済みの保存先に限定して `rg --hidden --no-ignore` を使う。次のパスと検索語は実際の対象に置き換える。

```sh
rg --hidden --no-ignore -n -i --glob '*.md' --glob '!README.md' \
  -- '検索語' '/absolute/common-dir/project-context/canonical/user'
```

既存構造への必要な参照・追加・更新は、その都度の指示を待たずに行える。一方、未導入プロジェクトの初期導入や構造修復は、ユーザーが依頼した対象・範囲に限る。

会話全文、秘密情報、認証情報、不要な個人情報、非公開顧客データ、生のツール出力、日常的なログ、作業用の一時記録は蓄積しない。現在のリポジトリから簡単に再構成できる情報も、通常は保存しない。本書のような構造説明はリポジトリの文書として管理し、個別コンテキストへ重複保存しない。

## 5. 管理元と配布先

以下の管理元は、このdotfilesのルートからの相対パス。構成は `denix` モジュールで定義し、システム構成に統合されたHome Managerで配布する。関連モジュールは現在 `macbook` のDarwin環境を対象にしている。

| 管理元 | 配布先・役割 |
| --- | --- |
| `modules/vault-context/files/shared/global-rules.md` | CodexとClaude Codeの共通ルール |
| `modules/vault-context/files/codex/AGENTS.md` | Codex固有部。共通ルールと結合して `~/.codex/AGENTS.md` |
| `modules/vault-context/files/claude/CLAUDE.md` | Claude Code固有部。共通ルールと結合して `~/.claude/CLAUDE.md` |
| `modules/pi-coding-agent/files/AGENTS.md` | `~/.pi/agent/AGENTS.md` |
| `modules/vault-context/files/codex/project-context-protocol.md` | `~/.codex/project-context-protocol.md` と `~/.pi/agent/project-context-protocol.md` |
| `.agents/skills/project-context-init/SKILL.md` | `~/.agents/skills/project-context-init/SKILL.md` |
| `.agents/skills/project-context-promote/SKILL.md` | `~/.agents/skills/project-context-promote/SKILL.md` |
| `modules/vault-context/files/project-context-init.py` | `~/.local/bin/project-context-init` の実装 |
| `modules/vault-context/default.nix` | Codex向けファイル、初期化コマンド、旧Vaultランタイムの配布 |
| `modules/codex-skills/default.nix` | リポジトリ管理スキルの配布 |
| `modules/pi-coding-agent/default.nix` | Pi向けルールと共有プロトコルの配布 |

配布先のファイルを直接編集するのではなく、対応する管理元を変更する。Home Managerの反映前には差があり得るため、管理元と配布済みファイルを別々に確認する。

このリポジトリでは、Nix全体の評価・ホストビルド・switchは明示依頼がある場合だけ行う。必要時は `nh` を使い、switchでは現在のriceに対応する構成を確認する。Markdownの引き継ぎ資料を作るだけなら、システム反映は不要。

## 6. 初期導入・構造修復

依頼を受けたときに `project-context-init` スキルを使う。現環境ではHome Managerの反映待ちでも最新の構造を使えるよう、管理元スクリプトを優先する。

```sh
python3 ~/.dotfiles/modules/vault-context/files/project-context-init.py \
  "/absolute/project/root" --title "Project name"
```

管理元がない配布先環境では、同じ引数を `project-context-init` コマンドに渡す。上記は初期化・修復を行うコマンドであり、読み取り専用の確認コマンドではない。

- `--git-backup --remote <url>`: 正本を独立したGitリポジトリにし、リポジトリごとに指定したprivate remoteをoriginにする。コミット・pushはしない。originが別のURLなら停止する。Git共通ディレクトリ内に入れ子になっても、本体のstatus・worktree・cloneには影響しない。
- `--reindex`: 既存の `INDEX.md` だけを再生成する。frontmatterが不正な記録があれば書き換えずに停止する。

初期化処理は正本・入口の準備と既知のテンプレート更新を担当する。v3以前のHTML記録が残る正本はv4へ更新せず停止するので、ユーザーの承認を得て変換前の状態を正本のリポジトリにコミットしてから、Markdownへ変換する。既存記録を自動生成したり、個々の内容を自動分類したりはしない。旧 `sources/` がある場合は内容を変えず `canonical/sources/` へ移し、移動先が既にある場合は統合・上書きせず停止する。保存先の衝突や不正なシンボリックリンクなども、削除して強行せず原因を確認する。

v2以前の `canonical` にはAIが整理した文章も含まれ得る。ディレクトリ名だけで人間の原文と判定しない。必要な旧記録は由来を確認し、AIによる文章は内容を保持して `ai_output/` の該当分類へ移す。原文が不明なら、その旨を明記して創作しない。

## 7. 旧Vault・MCP・定期処理との関係

`vault-context` というモジュール名は残っているが、通常の保存先は各プロジェクトのコンテキストである。旧Obsidian VaultやNotionを通常の保存先として使う運用ではない。

ローカルのプロジェクトコンテキストがなく過去情報が必要な場合、旧判断の確認、旧中央プロトコルが必要な場合などに限り、旧Vaultのルーティングと検索を使う。

```sh
~/.codex/bin/vault-context route --cwd "/absolute/project/root" --json
```

旧MCPランタイムは `~/.codex/mcp/vault-context-mcp/` に置かれ、Home Managerのactivationから同期する。`vault-context` と `codex-context` は同じ旧CLIへの入口。これはプロジェクトコンテキストを中央へ同期する仕組みではない。

管理文書では、旧「Vault朝次整理」「Vault週次統合」「Vault Git同期」は2026-09-13に廃止された。日常のコンテキスト管理は必要時の参照・保存で完結し、定期的なVault整理、検索インデックス保守、KPI収集、LINE通知を必要としない。残存する `vault-git-sync` は旧Vault用の手動ツールであり、プロジェクトコンテキストのバックアップには `project-context-init --git-backup` を使う。

## 8. 他の人・端末へ引き継ぐ場合

**ルールとツールはGitから取得できるが、プロジェクトコンテキストの記録は本体のcloneだけでは移らない。** `--git-backup` を設定した正本は、そのremoteから正本の位置へcloneすれば移せる。設定していない正本は、リポジトリの削除、再clone、別端末への移動で失われる。

構造だけを説明する場合は本書を渡せばよい。実際の記録も引き継ぐ場合は、次を分けて扱う。

1. 管理ルール・ツール: 本書と、必要な管理元ファイル・実装を渡す。
2. 記録: 対象プロジェクトの正本を解決し、共有が許される原文・資料・AI出力を選ぶ。AI出力の出典参照も維持する。
3. 移送先: Git共通ディレクトリまたは非Gitのプロジェクトルートを確認し、入口のシンボリックリンクを移送先に合わせる。移送先の既存記録へ無条件に上書きしない。
4. 確認: ディレクトリ構造、リンク先、資料への参照を確認する。Gitとは別に必要なバックアップを用意する。

このdotfilesの配布処理は所有者の環境向けで、一部に絶対パスがある。他人の端末へそのまま適用する汎用インストーラーではない。第三者が導入する場合は、ホームディレクトリと配布対象ホストを読み替える必要がある。

## 9. 移行状況

v4の規則・初期化処理・スキルは2026-11-11にswitchで配布した。2026-11-12時点で、共同・業務用と確定した7つの正本（kia、tokiwa、overseassales-dev、Play-Motion、iniad_moocs_ios、オープンデータハッカソン、ict-e-source）をv4へ更新した。各正本のローカルrepositoryの最初のcommitに変換前の状態を残しており、remoteは未設定。個人repositoryと非Git projectの正本はv2・v3のままで、扱いは別途決める。個々の記録の正しさ、バックアップの実在、旧MCPサーバーの疎通は検証していない。

## 10. 一次資料

以下のリンクは、このファイルをリポジトリ内で開いた場合の参照先。

- [共有プロトコル](files/codex/project-context-protocol.md)
- [共通ルール](files/shared/global-rules.md)
- [Codex固有ルール](files/codex/AGENTS.md)
- [Claude Code固有ルール](files/claude/CLAUDE.md)
- [Pi共通ルール](../pi-coding-agent/files/AGENTS.md)
- [初期化スキル](../../.agents/skills/project-context-init/SKILL.md)
- [移動スキル](../../.agents/skills/project-context-promote/SKILL.md)
- [初期化の実装](files/project-context-init.py)
- [配布モジュール](default.nix)
- [Pi配布モジュール](../pi-coding-agent/default.nix)
- [スキル配布モジュール](../codex-skills/default.nix)
- [旧Vault定期処理の廃止記録](files/codex/automations/README.md)
- [旧MCPランタイムの同期処理](files/sync-vault-context-runtime)

このMarkdownだけを渡した場合も、本文のパス・構造・運用説明から全体像を把握できる。実装や最新の規則を変更する場合は、元のリポジトリにある一次資料を確認する。
