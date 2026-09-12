# 仕訳の登録・検索・修正・削除と仕訳例

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## ステップ3: 仕訳の登録

ユーザーが確認したデータを帳簿に登録する。

### 3-1. 単一仕訳の登録（`journal-add`）

```bash
# journal.json に JournalEntry を JSON で記述
shinkoku ledger journal-add \
  --db-path DB --fiscal-year 2025 --input journal.json
```

`journal.json` の形式:
```json
{
  "date": "2025-01-15",
  "description": "摘要テキスト",
  "lines": [
    {"side": "debit", "account_code": "5200", "amount": 1000},
    {"side": "credit", "account_code": "1100", "amount": 1000}
  ]
}
```

### 3-2. 一括仕訳登録（`journal-batch-add`）

CSV取り込み等で複数の仕訳を一度に登録する場合に使用する。

```bash
# entries.json に JournalEntry の配列を記述
shinkoku ledger journal-batch-add \
  --db-path DB --fiscal-year 2025 --input entries.json [--force]
```

**登録前の確認事項:**

- 登録件数と合計金額をサマリーとして提示する
- 「以下の N 件の仕訳を登録します。よろしいですか？」と確認する
- ユーザーの明示的な承認を得てから `journal-batch-add` を実行する

### 登録時の検証ルール

以下を検証し、不備があれば登録前に警告する:

1. **日付の妥当性**: 会計年度の範囲内であるか（例: 2025-01-01 〜 2025-12-31）
2. **勘定科目の存在**: 借方・貸方の科目コードがマスタに存在するか
3. **金額の正値**: 金額が正の整数であるか
4. **貸借の一致**: 複合仕訳の場合、借方合計 = 貸方合計であるか
5. **消費税区分の整合**: 科目の tax_category と税率の組み合わせが妥当か

## ステップ4: 仕訳の検索

登録済みの仕訳を検索する。

### `search` コマンド

```bash
# search_params.json に JournalSearchParams を記述
shinkoku ledger search \
  --db-path DB --input search_params.json
```

`search_params.json` の形式:
```json
{
  "fiscal_year": 2025,
  "date_from": "2025-01-01",
  "date_to": "2025-03-31",
  "account_code": "5200",
  "description_contains": "Amazon"
}
```

**検索結果の表示:**

- 検索結果を日付順の一覧表で表示する
- 各仕訳には journal_id を表示する（修正・削除で使用）
- 合計金額を末尾に表示する

## ステップ5: 仕訳の修正・削除

### 5-1. 仕訳の修正（`journal-update`）

```bash
shinkoku ledger journal-update \
  --db-path DB --fiscal-year 2025 --journal-id 42 --input updated.json
```

- 修正前後の差分を表示してから確認する
- 修正理由を摘要に追記することを推奨する

### 5-2. 仕訳の削除（`journal-delete`）

```bash
shinkoku ledger journal-delete \
  --db-path DB --journal-id 42
```

- 削除対象の仕訳内容を表示して確認する
- 「この仕訳を削除します。よろしいですか？」と最終確認する
- 削除は取り消しできない旨を注意喚起する

## よくある仕訳パターン

### 売上の計上

```
借方: 売掛金(1010) / 貸方: 売上(4001)   金額: 110,000円  税率: 10%
摘要: ○○社 Webサイト制作費 請求書No.2025-001
```

### 経費の支払い（事業用口座から）

```
借方: 消耗品費(5190) / 貸方: 普通預金(1002)  金額: 5,500円  税率: 10%
摘要: Amazon ワイヤレスキーボード
```

### 個人の財布から事業経費を支払った場合

```
借方: 旅費交通費(5130) / 貸方: 事業主借(3010)  金額: 1,200円  税率: 10%
摘要: JR 新宿→渋谷 打ち合わせ往復
```

### 事業資金を個人利用した場合

```
借方: 事業主貸(1200) / 貸方: 普通預金(1002)  金額: 50,000円
摘要: 生活費引き出し
```

## 次のステップの案内

仕訳入力が完了したら、以下を案内する:

- `settlement` スキルで決算整理・決算書作成を行う
- `trial-balance` コマンドで残高試算表を確認して仕訳漏れがないか検証する:
  ```bash
  shinkoku ledger trial-balance \
    --db-path DB --fiscal-year 2025
  ```
- 全取引の登録完了を確認してから決算処理に進む
