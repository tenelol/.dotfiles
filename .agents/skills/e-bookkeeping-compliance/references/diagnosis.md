この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

# 優良な電子帳簿コンプライアンス診断

税務調査への備え、または優良な電子帳簿の要件充足状況を診断するスキル。
電子帳簿保存法施行規則第5条第5項（優良な電子帳簿の要件）に基づき、
shinkoku の帳簿データが要件を満たしているかを自動チェックする。

## 前提知識

- 電帳法の要件詳細: /tax-ebookkeeping-context を実行する
- システム概要書: `docs/system-overview.md`

---

## Step 0: 前提確認

ユーザーに以下を確認する:

1. **DB パス**: `--db-path` に使用するデータベースファイルのパス
2. **対象年度**: `--fiscal-year` に使用する会計年度
3. **届出書の提出状況**: 「国税関係帳簿の電磁的記録等による保存等に係る届出書」を所轄税務署に提出済みか

> **届出について**: 優良な電子帳簿の保存を適用するには、あらかじめ届出書の提出が必要です。
> 令和9年分から適用する場合は、令和8年中に届出書を提出する必要があります。
> 届出書の様式は国税庁ウェブサイトからダウンロードできます。

---

## Step 1: 自動診断 & サマリー出力

以下のコマンドを実行してシステムの適合状況を診断する。
結果はテーブル形式でユーザーに提示する。

### チェック項目と実行コマンド

| # | 要件 | 条文 | チェック方法 |
|---|------|------|------------|
| G1 | システム関係書類の備付け | 施行規則2条2項1号 | `docs/system-overview.md` ファイルの存在を確認 |
| G2 | 見読可能性の確保 | 施行規則2条2項2号 | `shinkoku ledger trial-balance --db-path <db> --fiscal-year <year>` を実行し、正常出力を確認 |
| G3 | ダウンロード対応 | 施行規則2条2項3号 | `shinkoku ledger search --db-path <db> --input <params> --format csv` を実行し、CSV出力を確認 |
| G4 | 訂正・削除履歴 | 施行規則5条5項1号イ | `shinkoku ledger audit-log --db-path <db>` を実行し、テーブルが機能することを確認 |
| G5 | 相互関連性の確保 | 施行規則5条5項1号ロ | `shinkoku ledger general-ledger --db-path <db> --fiscal-year <year> --account-code <code>` を実行し、仕訳帳⇔総勘定元帳の関連を確認 |
| G6 | 取引先検索 | 施行規則5条5項1号ハ | `counterparty_contains` パラメータで検索を実行 |
| G7 | 日付・金額の範囲指定検索 | 施行規則5条5項1号ハ | `date_from`/`date_to`/`amount_min`/`amount_max` パラメータで検索を実行 |
| G8 | 組合せ検索 | 施行規則5条5項1号ハ | 日付+取引先+金額を組み合わせた検索を実行 |

### 診断手順

1. G1: `docs/system-overview.md` の存在を確認する
2. G2: 残高試算表を生成する
   ```bash
   shinkoku ledger trial-balance --db-path <db> --fiscal-year <year>
   ```
3. G3: 仕訳をCSV形式で出力する
   ```bash
   shinkoku ledger search --db-path <db> --input <params> --format csv
   ```
   （params には `{"fiscal_year": <year>, "limit": 5}` を指定）
4. G4: 監査ログを取得する
   ```bash
   shinkoku ledger audit-log --db-path <db>
   ```
5. G5: 任意の勘定科目で総勘定元帳を出力する（仕訳が存在する科目を使用）
   ```bash
   shinkoku ledger general-ledger --db-path <db> --fiscal-year <year> --account-code <code>
   ```
6. G6-G8: 検索機能のテスト
   ```bash
   # G6: 取引先検索
   shinkoku ledger search --db-path <db> --input <params>
   # params: {"fiscal_year": <year>, "counterparty_contains": "<取引先名の一部>"}

   # G7: 範囲指定検索
   # params: {"fiscal_year": <year>, "date_from": "<開始日>", "date_to": "<終了日>", "amount_min": 1, "amount_max": 1000000}

   # G8: 組合せ検索
   # params: {"fiscal_year": <year>, "date_from": "...", "counterparty_contains": "...", "amount_min": 1}
   ```

### サマリー出力形式

診断結果を以下のテーブル形式で出力する:

```
## 優良な電子帳簿 コンプライアンス診断結果

| # | 要件 | 条文 | 結果 | 備考 |
|---|------|------|------|------|
| G1 | システム関係書類 | 施行規則2条2項1号 | ✓ / ✗ | ... |
| G2 | 見読可能性 | 施行規則2条2項2号 | ✓ / ✗ | ... |
| G3 | ダウンロード対応 | 施行規則2条2項3号 | ✓ / ✗ | ... |
| G4 | 訂正・削除履歴 | 施行規則5条5項1号イ | ✓ / ✗ | ... |
| G5 | 相互関連性 | 施行規則5条5項1号ロ | ✓ / ✗ | ... |
| G6 | 取引先検索 | 施行規則5条5項1号ハ | ✓ / ✗ | ... |
| G7 | 範囲指定検索 | 施行規則5条5項1号ハ | ✓ / ✗ | ... |
| G8 | 組合せ検索 | 施行規則5条5項1号ハ | ✓ / ✗ | ... |
```

不適合項目がある場合は、対応方法を案内する。

---
