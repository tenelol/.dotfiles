---
name: ask-claude
description: "CodexからClaude Code CLIに質問・レビュー・限定した実装を委譲する。ユーザーが「Claudeに聞いて」「Claudeでレビューして」「Claudeに任せて」と依頼したときに使う。"
---

# Ask Claude

既存のClaude Code CLIとログインを使い、非対話の`claude -p`で呼び出す。

## 呼び出し

1. `command -v claude`、`claude --version`、`claude auth status`で利用可能か確認する。未導入・未認証ならその状態を報告し、ログインやインストールは別途依頼を受けて行う。認証出力の個人情報は回答へ転載しない。
2. 対象の作業ディレクトリを指定する。プロンプトには目的、対象ファイル・差分、既知の制約、編集可否、期待する出力、検証条件を必要な範囲で含める。Codexの会話はClaudeに引き継がれない。
3. 質問・レビューは下記の読み取り専用コマンドで実行する。対象パスと依頼文を実際のものに置き換え、引用したheredocでシェル展開を防ぐ。モデルはClaudeの既存設定を使い、ユーザーが指定した場合だけ`--model`を加える。

```sh
cd /absolute/path/to/project
claude -p --output-format text --no-session-persistence \
  --tools 'Read,Glob,Grep' --allowedTools 'Read,Glob,Grep' \
  --permission-mode dontAsk --strict-mcp-config <<'CLAUDE_PROMPT'
次の依頼を読み取り専用で調査してください。
目的: …
対象ファイル・差分: …
制約: …
出力: 結論、根拠のファイルと行番号、未確認事項を日本語で簡潔に。
CLAUDE_PROMPT
```

プロンプトだけで回答できる質問は`--tools ''`を使い、`--allowedTools`を省く。差分は親が取得して渡せば、ClaudeへBash権限を与えずにレビューできる。`--strict-mcp-config`は既存のMCP接続を読み込ませないために使う。

## 実装の委譲

ユーザーがClaudeによる編集を依頼済みなら、その範囲で`--tools`に必要なツール名（`Edit,Write,Bash`など）、`--allowedTools`に許可する操作だけを追加する。Bashの許可は`Bash(git diff *)`のように具体的に絞り、プロンプトにも編集対象と実行可能な検証を明記する。同じファイルを親とClaudeで同時に編集しない。

`dontAsk`を保ち、権限不足なら必要な操作と失敗を報告する。権限バイパスや未許可のpush・merge・deploy・外部送信へ切り替えない。

## 結果の確認

- 実行中のセッションは既存のコマンド実行ツールで待ち、途中出力や終了コードを確認する。認証・権限・利用上限のエラーでは自動再試行を重ねない。
- Claudeの回答を根拠と照合し、編集があれば親がdiffと許可された検証を確認する。回答と実施済みの操作を区別し、未確認事項を残す。

CLIの詳細は[公式CLIリファレンス](https://code.claude.com/docs/en/cli-reference)と[非対話実行の説明](https://code.claude.com/docs/en/headless)を参照する。
