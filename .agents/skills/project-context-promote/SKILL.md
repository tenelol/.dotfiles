---
name: project-context-promote
description: project contextのai_outputをrepositoryのdocs等へ移すとき、または未確認の記録を一次情報と照合するときに使う。
---

# Project Context Promote

project contextの下書きのうち確定したものを、repositoryの`docs/`等へ移す。このスキルが作るのは作業ツリー上の差分までで、本体repositoryのcommit・pushはユーザーが行う。

## 準備

1. 正本を`~/.codex/project-context-protocol.md`の手順で解決し、`INDEX.md`を読む。`INDEX.md`のない旧正本（個人repositoryの移行など）では、`rg -n '^(title|summary|status|promoted_to):' <context-root>/ai_output`で同じ一覧を作る。
2. 対象repositoryの`docs/`・`README.md`・`AGENTS.md`/`CLAUDE.md`の構成と慣例（ADRの番号・雛形、見出し、言語）を確認する。

ユーザーが確認支援を求めたら「確認支援」、移動を求めたら「移動」へ進む。どちらとも言われていなければ、両方の候補数を示して選んでもらう。

## 確認支援

1. `promoted_to: null`かつ`status: unverified`の記録を、title・summary・作成日つきで一覧にする。
2. ユーザーが選んだ記録ごとに、本文の主張を一つずつ`sources`の原文・資料と現在の一次情報（repository、docs、issue、PR、CI、runtime）で照合する。
3. 記録ごとに「確認できた」「食い違う」「確認できない」と、その根拠の場所を報告する。食い違う記録は、更新案・削除案・現状維持のどれにするかユーザーに決めてもらう。
4. ユーザーが同意した記録だけ、`status: verified`と、確認日と根拠を書いた`status_note`へ更新する。`approved`はユーザーが承認と明言した記録だけに付ける。

照合した記録すべてに3の判定が付き、同意した分のfrontmatterが更新されたら完了とする。

## 移動

1. 候補は`promoted_to: null`かつ`status`が`verified`か`approved`の記録とする。`unverified`の記録は確認支援を先に済ませる。
2. 記録ごとに移動先を決める。
   - `decisions/` → `docs/adr/`（既存の番号・雛形に合わせる）
   - `workflows/` → `docs/`、またはエージェント向けの手順ならrepository内の`AGENTS.md`/`CLAUDE.md`
   - `facts/` → `docs/`。repositoryのコード・設定・`--help`ですぐ分かるものは移さない
   - `risks/`・`open_questions/` → ローカルに残す。issueにする価値があるものはissue本文の案を示し、作成はユーザーに任せる
3. 移す内容を、repositoryの読者向けの文章に書き直す。docsに入れてよいのは、repositoryの読者が一次情報で確かめられる結論と理由だけである。生の発言の引用、顧客資料の抜粋、secret・credential・個人情報、ローカルにしかないパス（`/Users/`、`~/`、`context/`、`canonical/`、`ai_output/`、`.git/project-context`）は書かず、必要なら公開済みの一次情報へのリンクに置き換える。
4. 作業ツリーへは書かず、移動先ごとの差分（新規fileは全文、既存fileはunified diff）と、移さない記録とその理由をユーザーに示す。
5. ユーザーが承認した差分だけを作業ツリーへ書き込む。書き込んだfileに対して`rg -n '/Users/|~/|context/|canonical/|ai_output/|project-context' <files>`を実行し、該当があれば直してから先へ進む。
6. 書き込んだfileがあることを確認してから、移した記録の本文を消してfrontmatterだけを残し、`promoted_to`にrepository rootからの相対パスを書く。
7. `INDEX.md`のある正本では`project-context-init <project root> --reindex`を実行する。正本の直下に`.git`があれば正本のrepositoryだけでローカルcommitする。なければcommitせず、`--git-backup`での導入を提案する。
8. 本体repositoryの`git status`と変更fileの一覧を示して終える。

承認したすべての記録について、移動先fileが作業ツリーにあり、5の検査に該当がなく、記録の`promoted_to`が設定されてINDEXに反映されていれば完了とする。承認されなかった記録とdocsには手を付けない。
