---
name: reading-deduction-cert
description: "控除証明書の画像・PDFから生命保険料や地震保険料等を構造化して読み取るときに使う。"
---

# 控除証明書 画像読み取り

控除証明書（生命保険料控除証明書、地震保険料控除証明書、社会保険料控除証明書等）の画像を読み取り、構造化データとして返すスキル。

## PDF ファイルの場合

ファイルが PDF（`.pdf`）の場合、画像 OCR の前にテキスト抽出を試みる。

1. `shinkoku pdf extract-text --file-path <path>` を実行する
2. 抽出テキストに必要な情報（保険料額・証明額等）が含まれていれば、テキストから構造化データを生成する
3. テキストが不十分（スキャン PDF 等）の場合は `shinkoku pdf to-image --file-path <path> --output-dir <dir>` で PNG に変換し、以下の画像読み取りフローに進む

## 画像読み取りと確認

利用可能な画像表示機能で原本を読み取り、主要な日付・金額・合計を照合する。PDFで必要なテキストが取れる場合は不要な画像化をしない。

独立した照合が有効な難読資料・重要な差異があり、委譲が許可されている場合だけ `subagent-model-router` のreview経路で追加確認する。サブエージェントを使わない指定は尊重し、親が原本を再確認する。

読み取りが一致しても原本の正しさを保証するとは説明しない。未確認の金額、合計不一致、判読不能な項目だけユーザーに確認し、独立検証を行っていない場合はそのように報告する。既に確認済みの値は再質問しない。

## 基本ルール

- 画像ファイルは現在の環境の画像表示ツールで読み取る
- 金額は必ず int（円単位の整数）で返す。カンマや「円」は除去する
- 日付は YYYY-MM-DD 形式で返す
- 和暦は西暦に変換する（令和7年 → 2025、令和6年 → 2024、平成31年 → 2019）
- 既存の出力形式では判読不能な文字列を UNKNOWN、金額を 0 とするが、この0は未確認のplaceholderとして該当項目を別記する。確認前に確定額として計算・登録しない

## 対象書類

- 生命保険料控除証明書
- 地震保険料控除証明書
- 社会保険料（国民年金保険料）控除証明書
- 小規模企業共済等掛金払込証明書（iDeCo含む）

## 出力フォーマット

JSON オブジェクトとして返す。金額は必ず int（円単位の整数）とする。

### 生命保険料控除証明書

```json
{
  "certificate_type": "life_insurance",
  "policy_type": "新制度 or 旧制度",
  "category": "一般 or 介護医療 or 個人年金",
  "company_name": "保険会社名",
  "policy_number": "証券番号",
  "annual_premium": 120000,
  "dividend": 0
}
```

### 地震保険料控除証明書

```json
{
  "certificate_type": "earthquake_insurance",
  "company_name": "保険会社名",
  "policy_number": "証券番号",
  "annual_premium": 50000,
  "is_old_long_term": false
}
```

### 社会保険料控除証明書

```json
{
  "certificate_type": "social_insurance",
  "insurance_type": "national_pension",
  "annual_premium": 200000,
  "period": "対象期間"
}
```

### 小規模企業共済等掛金払込証明書

```json
{
  "certificate_type": "small_business_mutual_aid",
  "sub_type": "ideco or small_business or disability",
  "annual_contribution": 276000
}
```

## 抽出のポイント

- 書類の種別（生命保険料/地震保険料/社会保険料/小規模企業共済等）を最初に判定する
- 生命保険料控除は新旧制度の区別と、3区分（一般/介護医療/個人年金）の分類を確認する
- 地震保険料控除は旧長期損害保険かどうかの区別を確認する
- 金額は「証明額」「申告額」が異なる場合、「申告額」を使用する
- 保険会社名・証券番号は確認用に抽出する
