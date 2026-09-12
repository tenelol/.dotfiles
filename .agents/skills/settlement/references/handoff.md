# 決算結果の引継書

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## 引継書の出力

サマリー提示後、以下のファイルを Write ツールで出力する。
これにより、セッションの中断や Compact が発生しても次のステップで結果を引き継げる。

### ステップ別ファイルの出力

`.shinkoku/progress/06-settlement.md` に以下の形式で出力する:

```
---
step: 6
skill: settlement
status: completed
completed_at: "{当日日付 YYYY-MM-DD}"
fiscal_year: {tax_year}
---

# 決算整理・決算書作成の結果

## 損益計算書（PL）サマリー

- 売上高: {金額}円
- 売上原価: {金額}円
- 経費合計: {金額}円
- 青色申告特別控除前の所得: {金額}円

## 貸借対照表（BS）サマリー

- 資産合計: {金額}円
- 負債合計: {金額}円
- 純資産合計: {金額}円
- 貸借差額: {金額}円（一致/不一致）

## 決算整理仕訳の一覧

| 内容 | 借方科目 | 貸方科目 | 金額 |
|------|---------|---------|------|
| {減価償却費等} | {科目名} | {科目名} | {金額}円 |
（減価償却、地代家賃按分、棚卸調整、未払計上等を記載）

## 次のステップ

/income-tax で所得税の計算を行う
/consumption-tax で消費税の計算を行う
```

### 進捗サマリーの更新

`.shinkoku/progress/progress-summary.md` を更新する（存在しない場合は新規作成）:

- YAML frontmatter: fiscal_year、last_updated（当日日付）、current_step: settlement
- テーブル: 全ステップの状態を更新（settlement を completed に）
- 次のステップの案内を記載

### 出力後の案内

ファイルを出力したらユーザーに以下を伝える:
- 「引継書を `.shinkoku/progress/` に保存しました。セッションが中断しても次のスキルで結果を引き継げます。」
- 次のステップの案内
