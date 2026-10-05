---
name: imoocs
description: "INIAD MOOCsの授業・教材・課題・出席を扱うときに使う。対応操作はローカルimoocs CLIを優先する。"
---

# INIAD MOOCs

INIAD MOOCsに対する依頼を、利用可能なローカル `imoocs` CLIから処理する。教材・課題の対象を確認し、その操作に必要な参照だけ読む。

- CLIが対応する操作はCLIを優先し、未対応の画面だけ利用可能なブラウザへ進む。
- 認証情報やセッションを出力・成果物・contextへコピーしない。
- 課題の読取・下書き作成と、提出・出席等の実操作を区別し、実操作は既存の許可範囲内で行う。
- 取得済みの教材や確認済みの対象を再取得しない。
- 提出する回答は指定された一次資料・実データ・検証した計算で根拠を確認する。根拠が未確認の回答を推測で提出しない。提出前の基準は[課題手順](references/assignments.md#evidence-before-submission)を読む。
- 提出後は課題URLと回答反映を確認した実画面のスクリーンショットを提示する。CLIでの提出にも[画面確認手順](references/assignments.md#submission-screenshots)を適用する。

## 必要な操作だけ読む

該当する操作の参照だけ読み、別の操作の手順は必要になった時点で開く。

| 操作・条件 | 参照 |
| --- | --- |
| CLI優先・接続・認証・健全性 | [手順](references/cli.md) |
| MOOCs URLの解析と参照 | [手順](references/urls.md) |
| スライド・講義資料 | [手順](references/slides.md) |
| 授業に紐づくGoogle Drive資料 | [手順](references/drive.md) |
| 課題の確認・解答・承認済み提出 | [手順](references/assignments.md) |
| CLI未対応操作と結果報告 | [手順](references/unsupported.md) |
