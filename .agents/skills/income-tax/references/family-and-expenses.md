# 家族・医療費・共済・支払調書・損失繰越

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## ステップ1.5: 扶養親族・配偶者情報の確認

所得控除の計算前に、扶養親族の情報を収集する。
まず DB に登録済みのデータを確認し、不足があれば追加入力する。

### DB からの読み込み

1. `ledger.py get-spouse --db-path DB_PATH` で配偶者情報を取得する（登録済みの場合）
2. `ledger.py list-dependents --db-path DB_PATH` で扶養親族のリストを取得する（登録済みの場合）

### 未登録の場合の確認項目

1. **配偶者**: 配偶者の有無と年間所得金額を確認する
   - 所得48万円以下 → 配偶者控除（38万円）
   - 所得48万円超133万円以下 → 配偶者特別控除（段階的）
   - 納税者の所得が1,000万円超 → 配偶者控除なし
   - 確認後 `ledger.py set-spouse --db-path DB_PATH --input spouse.json` で DB に登録する

2. **扶養親族**: 以下の情報を収集する
   - 氏名、続柄、生年月日、年間所得、障害の有無、同居の有無
   - 16歳未満: 扶養控除なし（児童手当対象）
   - 16歳以上: 一般扶養38万円
   - 19歳以上23歳未満: 特定扶養63万円
   - 70歳以上: 老人扶養48万円（同居58万円）
   - 確認後 `ledger.py add-dependent --db-path DB_PATH --input dependent.json` で各人を DB に登録する

3. **マイナンバーの収集**（申告書B第二表に記載が必要）:
   - 配偶者のマイナンバー（12桁）
   - 扶養親族（16歳以上）全員のマイナンバー
   - 16歳未満の子供のマイナンバー（住民税に関する事項の記載に必要）
   - 取扱注意: DB に保存するが、ツール出力やログには表示しない

4. **事業専従者の確認**:
   - 配偶者が青色事業専従者として給与を受けている場合 → 配偶者控除の対象外
   - 扶養親族が青色事業専従者・白色事業専従者の場合 → 扶養控除の対象外
   - 該当する場合は控除計算から除外し、ユーザーに明示する

5. **障害者控除**: 扶養親族に障害がある場合
   - 一般障害者: 27万円、特別障害者: 40万円、同居特別障害者: 75万円

**重要: 16歳未満の扶養親族も必ず登録する**

16歳未満の子供は扶養控除の対象外だが、以下の理由で申告書への記載が必要:
- 住民税の非課税限度額の判定（扶養人数に16歳未満も含む）
- 住民税の均等割の非課税判定
- 申告書B第二表「住民税に関する事項 - 16歳未満の扶養親族」欄への記載

`ledger.py add-dependent` で登録する際、16歳未満でもスキップせずに登録すること。

## ステップ1.6: iDeCo・小規模企業共済の確認

掛金払込証明書がある場合は `import_data.py import-deduction-certificate` で取り込むことができる。

1. iDeCo（個人型確定拠出年金）の年間掛金を確認する
   - 小規模企業共済等掛金払込証明書から金額を確認
   - 全額が所得控除（上限: 自営業者は年額81.6万円）
2. 小規模企業共済の掛金がある場合も同様に確認する

#### 画像ファイルの場合: OCR 読み取り

`extracted_text` が空の場合（画像ファイルまたはスキャン PDF）、画像の読み取りは `/reading-deduction-cert` スキルを使用する。
スキルの指示に従い、デュアル検証（2つの独立した読み取り結果の照合）を行って結果を取得する。

**結果照合:** 両方の読み取り結果から `annual_premium`, `certificate_type` を比較する

**一致の場合:** そのまま採用。「2つの独立した読み取りで結果が一致しました」と報告

**不一致の場合:** ユーザーに元画像パスと両方の結果を提示し、正しい方を選択してもらう:
- 差異のあるフィールドを明示する
- A を採用 / B を採用 / 手動入力 の3択を AskUserQuestion で提示する

## ステップ1.7: 医療費明細の集計

医療費控除を適用する場合、明細を集計する。

### 医療費の登録・集計

1. `ledger.py list-medical-expenses --db-path DB_PATH --input query.json` で登録済み医療費明細を取得する
2. 未登録の医療費がある場合は `ledger.py add-medical-expense --db-path DB_PATH --input medical.json` で登録する:
   ```json
   {
     "fiscal_year": 2025,
     "detail": {
       "date": "2025-03-15",
       "patient_name": "山田太郎",
       "medical_institution": "ABC病院",
       "amount": 150000,
       "insurance_reimbursement": 0,
       "description": null
     }
   }
   ```
3. 集計結果（total_amount - total_reimbursement）を医療費控除の計算に使用する

## ステップ1.8: 事業所得の源泉徴収（支払調書）

取引先から受け取った支払調書の情報を登録する。

### 支払調書の取り込み

1. `import_data.py import-payment-statement --input payment_input.json` で支払調書PDF/画像からデータを抽出する

#### 画像ファイルの場合: OCR 読み取り

`extracted_text` が空の場合（画像ファイルまたはスキャン PDF）、画像の読み取りは `/reading-payment-statement` スキルを使用する。
スキルの指示に従い、デュアル検証（2つの独立した読み取り結果の照合）を行って結果を取得する。

**結果照合:** 両方の読み取り結果から `gross_amount`, `withholding_tax`, `payer_name` を比較する

**一致の場合:** そのまま採用。「2つの独立した読み取りで結果が一致しました」と報告

**不一致の場合:** ユーザーに元画像パスと両方の結果を提示し、正しい方を選択してもらう:
- 差異のあるフィールドを明示する
- A を採用 / B を採用 / 手動入力 の3択を AskUserQuestion で提示する

2. `ledger.py add-business-withholding --db-path DB_PATH --input withholding.json` で取引先別の源泉徴収情報を登録する:
   ```json
   {
     "fiscal_year": 2025,
     "detail": {
       "client_name": "取引先名",
       "gross_amount": 1000000,
       "withholding_tax": 102100
     }
   }
   ```
3. `ledger.py list-business-withholding --db-path DB_PATH --input query.json` で登録済み情報を確認する
4. 源泉徴収税額の合計を `business_withheld_tax` として所得税計算に使用する

## ステップ1.8.5: 税理士等報酬の登録

税理士・弁護士等に報酬を支払っている場合、報酬明細を登録する。

1. `ledger.py list-professional-fees --db-path DB_PATH --input query.json` で登録済みの税理士等報酬を確認する
2. 未登録の場合は `ledger.py add-professional-fee --db-path DB_PATH --input fee.json` で登録する:
   ```json
   {
     "fiscal_year": 2025,
     "detail": {
       "payer_address": "支払者住所",
       "payer_name": "税理士名",
       "fee_amount": 300000,
       "expense_deduction": 0,
       "withheld_tax": 30630
     }
   }
   ```
3. 源泉徴収税額は `business_withheld_tax` に合算する

## ステップ1.9: 損失繰越の確認

前年以前に事業で損失が発生し、青色申告している場合、繰越控除を適用できる。

1. `ledger.py list-loss-carryforward --db-path DB_PATH --input query.json` で登録済みの繰越損失を確認する
2. 未登録の場合は `ledger.py add-loss-carryforward --db-path DB_PATH --input loss.json` で登録する:
   ```json
   {
     "fiscal_year": 2025,
     "detail": {
       "loss_year": 2023,
       "amount": 500000
     }
   }
   ```
3. 繰越損失の合計を `loss_carryforward_amount` として所得税計算に使用する
