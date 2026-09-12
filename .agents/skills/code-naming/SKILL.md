---
name: code-naming
description: "識別子の意味や命名の改善を検討・レビューするときに使う。既存APIとrepository規約を尊重する。"
metadata:
  trigger: 識別子の命名、命名のレビュー、実装計画でのメソッド名・クラス名の決定
  language: ja
---

# コードの命名

新しい識別子や依頼範囲の改名について、名前から目的・取得方法・副作用を読めるようにする。言語、既存API、framework、repositoryの規約を優先する。

- I/Oなら `load` / `fetch`、検索なら `find` / `search`、計算なら `calculate` など、実際の動作を表す。単純なaccessorにまで一律の `get` 禁止を適用しない。
- `Manager` / `Helper` / `data` のような広い名前は、意味が曖昧になる場合に具体化する。既存の語彙を崩すためだけに改名しない。
- 真偽値は `isEmpty` / `hasChildren` / `canEdit` のように判定内容を示す。
- 対の操作、集合と要素、同じドメイン概念には一貫した語を使う。
- scope外の一括改名や、命名のためだけの設計変更は行わない。

迷う場合だけ参照する。例や避ける語は候補であり、互換性や既存規約より優先しない。

| 検討内容 | 参照 |
| --- | --- |
| 処理を表す動詞 | [verbs](references/verbs.md) |
| 真偽値 | [booleans](references/booleans.md) |
| 型・classの責務 | [class names](references/class-names.md) |
| 状態・時間等の修飾 | [modifiers](references/modifiers.md) |
