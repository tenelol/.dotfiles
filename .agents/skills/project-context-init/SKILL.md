---
name: project-context-init
description: ユーザーがプロジェクトのコンテキスト中間層の初期導入・構造修復を依頼したときに使う。通常の情報保存やプロジェクト作成だけでは使わない。
---

# Project Context Init

指定されたprojectに、原文・原資料を置く`canonical/`とAIの整理結果を置く`ai_output/`を準備する。対象rootはユーザーの指定または現在のprojectから確定し、別projectを一括処理しない。

既存の初期化処理を実行する。この環境ではHome Managerの反映待ちでも最新の構造を作れるよう、管理元スクリプトを使う。rootは絶対パスで引用し、表示名を指定したい場合だけ`--title`を付ける。

```sh
python3 /Users/tener/.dotfiles/modules/vault-context/files/project-context-init.py "/absolute/project/root" --title "Project name"
```

管理元がない環境では、配布済みの`project-context-init`コマンドに同じ引数を渡す。初期化処理をスキル内に複製しない。

- Git projectではGit common directoryの`project-context/`を使い、project rootの`context`をそこへのsymlinkにする。非Gitではrootの`context/`を使う。
- 作成先は`canonical/user/`、`canonical/sources/{internal,external}/`、`ai_output/{facts,decisions,workflows,risks,open_questions}/`。context全体はGit管理外にする。
- コマンドは既知の旧テンプレートだけ更新し、既存記録・独自編集を保持する。移動先の衝突やsymlinkの拒否が出たら、対象を確認して原因を報告し、削除・上書きで通さない。
- 完了後は保存先・directory構造・Gitの場合のsymlinkを確認する。記録は勝手に移行・生成せず、以後の参照・保存は生成されたREADMEと`~/.codex/project-context-protocol.md`に従う。
