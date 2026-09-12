# その他の所得・保険料内訳・寄附

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## ステップ1.10: その他の所得の確認（雑所得・配当所得・一時所得・年金所得・退職所得）

事業所得・給与所得以外の総合課税の所得を確認・登録する。

### 公的年金等の雑所得

公的年金等の収入がある場合、年金控除を計算して雑所得を求める。

1. 年金収入の有無を確認する
2. `uv run shinkoku tax calc-pension --input pension_input.json` で公的年金等控除を計算する:
   ```bash
   uv run shinkoku tax calc-pension --input pension_input.json
   ```
   入力 JSON:
   ```json
   {
     "pension_income": 2000000,
     "is_over_65": true,
     "other_income": 0
   }
   ```
   出力:
   ```json
   {
     "pension_income": 2000000,
     "deduction_amount": 1100000,
     "taxable_pension_income": 900000,
     "other_income_adjustment": 0
   }
   ```
3. `taxable_pension_income` を雑所得として `misc_income` に加算する
4. 令和7年改正: 65歳未満の最低保障額60万→70万、65歳以上の最低保障額110万→130万

### 退職所得

退職金を受け取った場合、退職所得を計算する。

1. 退職金の有無を確認する
2. `uv run shinkoku tax calc-retirement --input retirement_input.json` で退職所得を計算する:
   ```bash
   uv run shinkoku tax calc-retirement --input retirement_input.json
   ```
   入力 JSON:
   ```json
   {
     "severance_pay": 10000000,
     "years_of_service": 20,
     "is_officer": false,
     "is_disability_retirement": false
   }
   ```
   出力:
   ```json
   {
     "severance_pay": 10000000,
     "retirement_income_deduction": 8000000,
     "taxable_retirement_income": 1000000,
     "half_taxation_applied": true
   }
   ```
3. 退職所得は原則分離課税（退職時に源泉徴収済み）だが、確定申告で精算する場合もある
4. 役員等の短期退職（勤続5年以下）は1/2課税が適用されない

### 雑所得（miscellaneous）

副業の原稿料、暗号資産の売却益、その他の雑収入。

1. `ledger.py list-other-income --db-path DB_PATH --input query.json` で登録済み雑所得を確認する
2. 未登録の収入がある場合は `ledger.py add-other-income --db-path DB_PATH --input other_income.json` で登録する:
   ```json
   {
     "fiscal_year": 2025,
     "detail": {
       "income_type": "miscellaneous",
       "description": "収入の内容",
       "revenue": 500000,
       "expenses": 50000,
       "withheld_tax": 51050,
       "payer_name": "支払者名"
     }
   }
   ```
3. 雑所得 = 収入 - 経費（特別控除なし）

### 仮想通貨（暗号資産）

暗号資産の売却益は雑所得（総合課税）として申告する。

1. `ledger.py list-crypto-income --db-path DB_PATH --input query.json` で登録済み仮想通貨所得を確認する
2. 未登録の場合は `ledger.py add-crypto-income --db-path DB_PATH --input crypto.json` で取引所別に登録する:
   ```json
   {
     "fiscal_year": 2025,
     "detail": {
       "exchange_name": "取引所名",
       "gains": 300000,
       "expenses": 10000
     }
   }
   ```
3. 合計を雑所得として total_income に加算する

### 配当所得（総合課税選択分）

総合課税を選択した配当は配当控除（税額控除）の対象となる。

1. `ledger.py list-other-income --db-path DB_PATH --input query.json` で `income_type: "dividend_comprehensive"` を確認する
2. 未登録の場合は `ledger.py add-other-income --db-path DB_PATH --input dividend.json` で登録する
3. 配当控除: 課税所得1,000万以下の部分 → 配当の10%、超える部分 → 5%

### 一時所得

保険満期金、懸賞金等の一時的な所得。

1. `ledger.py list-other-income --db-path DB_PATH --input query.json` で `income_type: "one_time"` を確認する
2. 未登録の場合は `ledger.py add-other-income --db-path DB_PATH --input one_time.json` で登録する
3. 一時所得 = max(0, (収入 - 経費 - 特別控除50万円)) × 1/2

### `calc_income_tax` への反映

上記のその他所得は以下のパラメータで `calc_income_tax` に渡す:
- `misc_income`: 雑所得合計（仮想通貨含む）
- `dividend_income_comprehensive`: 配当所得（総合課税選択分）
- `one_time_income`: 一時所得の収入金額（1/2 計算は内部で実施）
- `other_income_withheld_tax`: その他所得の源泉徴収税額合計

## ステップ1.11: （対象外）分離課税

分離課税（株式・FX の第三表）は対象外。該当する場合は税理士への相談を案内する。

## ステップ1.12: 社会保険料の種別別内訳の登録

所得控除の内訳書に種別ごとの記載が必要なため、社会保険料を種別別に登録する。

社会保険料の控除証明書がある場合は `import_data.py import-deduction-certificate` で取り込むことができる。

1. `ledger.py list-social-insurance-items --db-path DB_PATH --input query.json` で登録済み項目を確認する
2. 未登録の場合は `ledger.py add-social-insurance-item --db-path DB_PATH --input insurance.json` で種別ごとに登録する:
   ```json
   {
     "fiscal_year": 2025,
     "detail": {
       "insurance_type": "national_health",
       "name": "保険者名",
       "amount": 300000
     }
   }
   ```
   insurance_type: national_health / national_pension / national_pension_fund / nursing_care / labor_insurance / other
3. 合計額を `social_insurance` として控除計算に使用する

## ステップ1.13: 保険契約の保険会社名の登録

所得控除の内訳書に保険会社名の記載が必要なため、保険契約を登録する。

控除証明書の画像・PDFがある場合は `import_data.py import-deduction-certificate` で取り込むことができる。
取り込み後、抽出データに基づいて `ledger.py add-insurance-policy` で登録する。

1. `ledger.py list-insurance-policies --db-path DB_PATH --input query.json` で登録済み項目を確認する
2. 未登録の場合は `ledger.py add-insurance-policy --db-path DB_PATH --input policy.json` で登録する:
   ```json
   {
     "fiscal_year": 2025,
     "detail": {
       "policy_type": "life_general_new",
       "company_name": "保険会社名",
       "premium": 80000
     }
   }
   ```
   policy_type: life_general_new / life_general_old / life_medical_care / life_annuity_new / life_annuity_old / earthquake / old_long_term
3. 生命保険料は `life_insurance_detail` パラメータに、地震保険料は `earthquake_insurance_premium` に反映する

## ステップ1.14: ふるさと納税以外の寄附金の確認

政治活動寄附金、認定NPO法人、公益社団法人等への寄附金を確認する。

1. `ledger.py list-donations --db-path DB_PATH --input query.json` で登録済み寄附金を確認する
2. 未登録の場合は `ledger.py add-donation --db-path DB_PATH --input donation.json` で登録する:
   ```json
   {
     "fiscal_year": 2025,
     "detail": {
       "donation_type": "npo",
       "recipient_name": "寄附先名",
       "amount": 50000,
       "date": "2025-06-01",
       "receipt_number": null
     }
   }
   ```
   donation_type: political / npo / public_interest / specified / other
3. 寄附金控除の計算:
   - **所得控除**: 全寄附金 - 2,000円（総所得金額の40%上限）
   - **税額控除（政治活動寄附金）**: (寄附金 - 2,000円) × 30%（所得税額の25%上限）
   - **税額控除（認定NPO等）**: (寄附金 - 2,000円) × 40%（所得税額の25%上限）
4. `calc_deductions` の `donations` パラメータに寄附金レコードのリストを渡す
