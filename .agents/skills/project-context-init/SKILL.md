---
name: project-context-init
description: ユーザーが共同・業務repositoryへのproject contextの初期導入・構造修復・backup設定を依頼したときに使う。通常の情報保存やプロジェクト作成だけでは使わない。
---

# Project Context Init

共同・業務repository向けの下書き置き場を、指定されたprojectに準備する。`INDEX.md`がこの運用の目印になるため、ユーザーが対象と範囲を指定したprojectだけを処理し、個人repositoryや別projectを一括処理しない。対象rootはユーザーの指定または現在のprojectから確定する。

既存の初期化処理を実行する。この環境ではHome Managerの反映待ちでも最新の構造を作れるよう、管理元スクリプトを使う。rootは絶対パスで引用し、表示名を指定したい場合だけ`--title`を付ける。backupはユーザーが求めた場合だけ`--git-backup`を付け、remoteはユーザーがそのrepository用に指定したURLだけを`--remote`に渡す。

```sh
python3 /Users/tener/.dotfiles/modules/vault-context/files/project-context-init.py "/absolute/project/root" --title "Project name" --git-backup --remote "<private remote URL>"
```

管理元がない環境では、配布済みの`project-context-init`コマンドに同じ引数を渡す。初期化処理をスキル内に複製しない。

- Git projectではGit common directoryの`project-context/`を使い、project rootの`context`をそこへのsymlinkにする。非Gitではrootの`context/`を使う。
- 作成先は`INDEX.md`、`canonical/user/`、`canonical/sources/{internal,external}/`、`ai_output/{facts,decisions,workflows,risks,open_questions}/`。context全体は本体repositoryのGit管理外にする。
- `--git-backup`は正本を独立したgit repositoryにしてoriginを設定するだけで、commit・pushはしない。originが別URLなら停止する。pushの前は`--preflight`を通し、`canonical/sources/internal/`の資料は`~/.codex/project-context-protocol.md`の「internalの重要資料」に従ってユーザーに分類を確認する。
- コマンドは既知の旧テンプレートだけ更新し、既存記録・独自編集を保持する。HTML記録の残るv3以前の正本、frontmatterの不備、移動先の衝突、symlinkで停止したら、対象を確認して原因を報告し、削除・上書きで通さない。HTML記録の変換はユーザーの承認を得てから行う。
- 完了後は保存先・directory構造・`INDEX.md`・Gitの場合のsymlink・backupのoriginを確認する。記録は勝手に移行・生成せず、以後の参照・保存は生成されたREADMEと`~/.codex/project-context-protocol.md`に従う。
