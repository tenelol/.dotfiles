# 所得控除・税額計算・sanity check・住宅ローン控除

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## ステップ2: 所得控除の計算

### `tax_calc.py calc-deductions` の呼び出し

```bash
shinkoku tax calc-deductions --input deductions_input.json
```
入力 JSON:
```json
{
  "total_income": 5000000,
  "social_insurance": 700000,
  "life_insurance_premium": 80000,
  "earthquake_insurance_premium": 30000,
  "medical_expenses": 200000,
  "furusato_nozei": 50000,
  "housing_loan_balance": 0,
  "spouse_income": null,
  "ideco_contribution": 276000,
  "dependents": [],
  "fiscal_year": 2025,
  "housing_loan_detail": null,
  "donations": null
}
```
出力 (DeductionsResult):
- `income_deductions`: 所得控除の一覧（basic_deduction, social_insurance_deduction, life_insurance_deduction, earthquake_insurance_deduction, ideco_deduction, medical_deduction, furusato_deduction, donation_deduction, spouse_deduction, dependent_deduction, disability_deduction）
- `tax_credits`: 税額控除の一覧（housing_loan_credit, political_donation_credit, npo_donation_credit）
- `total_income_deductions`: 所得控除合計
- `total_tax_credits`: 税額控除合計

**各控除の確認事項:**

- 基礎控除: 合計所得金額に応じた段階的控除（令和7年分の改正を反映、132万以下=95万）
- 社会保険料控除: 国民年金・国民健康保険・その他の年間支払額
- 生命保険料控除: 新旧制度 × 3区分（一般/介護医療/個人年金）で計算する
  - `life_insurance_detail` パラメータで5区分の保険料を指定:
    - `general_new`: 一般（新制度）、`general_old`: 一般（旧制度）
    - `medical_care`: 介護医療（新制度のみ）
    - `annuity_new`: 個人年金（新制度）、`annuity_old`: 個人年金（旧制度）
  - 各区分の上限: 新制度 40,000円 / 旧制度 50,000円 / 合算上限 40,000円
  - 3区分合計の上限: 120,000円
  - 源泉徴収票に生命保険料5区分の記載がある場合はそのまま使用する
- 地震保険料控除: 地震保険（上限5万円）+ 旧長期損害保険（上限1.5万円）、合算上限5万円
  - `old_long_term_insurance_premium` パラメータで旧長期損害保険料を指定可能
- 小規模企業共済等掛金控除: 3サブタイプ個別追跡
  - iDeCo（個人型確定拠出年金）
  - 小規模企業共済
  - 心身障害者扶養共済
  - `small_business_mutual_aid` パラメータで小規模企業共済掛金を指定
- 医療費控除: 支払額から保険金等の補填額を差し引き、10万円（または所得の5%）を超える部分
  - **セルフメディケーション税制との選択適用**: OTC医薬品の購入額 - 12,000円（上限 88,000円）
  - 医療費控除とセルフメディケーションは併用不可。有利な方を選択する
- 配偶者控除/特別控除: 配偶者の所得に応じて段階的に控除額が変動
- 扶養控除: 年齢区分に応じた控除額（一般38万/特定63万/老人48万or58万）
- 障害者控除: 障害の程度に応じた控除額
- **人的控除**（config の納税者情報から自動判定）:
  - 寡婦控除: 27万円（所得500万以下）
  - ひとり親控除: 35万円（所得500万以下）
  - 障害者控除（本人）: 一般 27万円 / 特別 40万円
  - 勤労学生控除: 27万円（所得75万以下）
- ふるさと納税: 寄附金 − 2,000円（確定申告ではワンストップ特例分も含める）
- 住宅ローン控除: 住宅区分別の年末残高上限と控除率0.7%（令和4年以降入居）

## ステップ3: 所得税額の計算

### `tax_calc.py calc-income` の呼び出し

```bash
shinkoku tax calc-income --input income_input.json
```
入力 JSON (IncomeTaxInput):
```json
{
  "fiscal_year": 2025,
  "salary_income": 5000000,
  "business_revenue": 3000000,
  "business_expenses": 1000000,
  "blue_return_deduction": 650000,
  "social_insurance": 700000,
  "life_insurance_premium": 80000,
  "earthquake_insurance_premium": 30000,
  "medical_expenses": 0,
  "furusato_nozei": 50000,
  "housing_loan_balance": 0,
  "spouse_income": null,
  "ideco_contribution": 276000,
  "withheld_tax": 100000,
  "business_withheld_tax": 30000,
  "estimated_tax_payment": 0,
  "loss_carryforward_amount": 0
}
```
出力 (IncomeTaxResult):
- `salary_income_after_deduction`: 給与所得控除後の金額
- `business_income`: 事業所得
- `total_income`: 合計所得金額（繰越損失適用後）
- `total_income_deductions`: 所得控除合計
- `taxable_income`: 課税所得金額（1,000円未満切り捨て）
- `income_tax_base`: 算出税額
- `total_tax_credits`: 税額控除合計
- `income_tax_after_credits`: 税額控除後
- `reconstruction_tax`: 復興特別所得税（基準所得税額 x 2.1%）
- `total_tax`: 所得税及び復興特別所得税の額（端数処理なし）
- `withheld_tax`: 源泉徴収税額（給与分）
- `business_withheld_tax`: 事業所得の源泉徴収税額
- `estimated_tax_payment`: 予定納税額
- `loss_carryforward_applied`: 適用した繰越損失額
- `tax_due`: 申告納税額（= total_tax - withheld_tax - business_withheld_tax - estimated_tax_payment）

**寄附金控除の反映:**

ふるさと納税以外の寄附金控除（ステップ1.14で登録）は、`calc_deductions` の結果に含まれている。
`calc_income_tax` は内部で `calc_deductions` を呼び出すため、以下のパラメータが正しく渡されていれば自動的に反映される:
- `furusato_nozei`: ふるさと納税の寄附金合計
- 政治活動寄附金・認定NPO等の税額控除は `calc_deductions` の `donations` パラメータ経由で計算される

所得税計算前に `calc_deductions` を個別に呼び出す場合は、`donations` パラメータにステップ1.14で登録した寄附金レコードのリストを必ず渡すこと。

**青色申告特別控除の自動キャップ:**

`blue_return_deduction` は config の値をそのまま渡してよい。計算エンジンが事業利益を上限として自動キャップする（租特法25条の2）。
結果の `effective_blue_return_deduction` と `warnings` を必ず確認すること。

**計算結果の確認:**

1. 合計所得金額の内訳を表示する
2. `effective_blue_return_deduction` を確認し、自動調整があれば `warnings` の内容を表示する
3. 繰越損失が適用されている場合はその額を明示する
4. 所得税の速算表の適用が正しいか確認する
5. 復興特別所得税が正しく加算されているか確認する
6. 源泉徴収税額（給与分 + 事業分）が正しく控除されているか確認する
7. 予定納税額が正しく控除されているか確認する
8. 最終的な納付額（または還付額）を明示する

所得税の速算表・配偶者控除テーブル・住宅ローン限度額等は `references/deduction-tables.md` を参照。

## ステップ3.1: サニティチェック（必須）

`calc-income` の結果を自動検証する。このステップはスキップ不可。

### `tax_calc.py sanity-check` の呼び出し

```bash
shinkoku tax sanity-check --input sanity_input.json
```
入力 JSON:
```json
{
  "input": { ... },
  "result": { ... }
}
```
- `input`: ステップ3で `calc-income` に渡した IncomeTaxInput
- `result`: ステップ3で `calc-income` から返された IncomeTaxResult

出力 (TaxSanityCheckResult):
- `passed`: true/false
- `items`: チェック項目のリスト（severity, code, message）
- `error_count`: エラー件数
- `warning_count`: 警告件数

### 結果に応じた対応

- **error > 0**: 計算結果に問題があります。エラー内容を確認し、入力を修正してステップ3を再実行してください
- **warning > 0**: 警告内容をユーザーに提示し、確認してから続行してください
- **passed = true**: 問題なし。次のステップに進む

## ステップ3.5: 住宅ローン控除明細の DB 登録（該当者のみ）

住宅ローン控除（初年度）を適用する場合、詳細情報を DB に登録する。

1. `ledger.py add-housing-loan-detail --db-path DB_PATH --input housing.json` で住宅ローン控除の明細を登録する:
   ```json
   {
     "fiscal_year": 2025,
     "detail": {
       "housing_type": "new_custom",
       "housing_category": "certified",
       "move_in_date": "2024-03-15",
       "year_end_balance": 30000000,
       "is_new_construction": true,
       "is_childcare_household": false,
       "has_pre_r6_building_permit": false,
       "purchase_date": "2024-01-20",
       "purchase_price": 40000000,
       "total_floor_area": 8000,
       "residential_floor_area": 8000,
       "property_number": null,  // 不動産番号（13桁）を入力すると登記事項証明書の添付省略可（令和3年度改正）
       "application_submitted": false
     }
   }
   ```

住宅区分別の年末残高上限テーブルは `references/deduction-tables.md` を参照。

## ステップ6: 計算結果サマリーの提示

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
所得税の計算結果（令和○年分）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

■ 所得金額（総合課税）
  事業所得:           ○○○,○○○円
  給与所得:           ○○○,○○○円
  雑所得:             ○○○,○○○円（該当者のみ）
  配当所得:           ○○○,○○○円（総合課税分、該当者のみ）
  一時所得:           ○○○,○○○円（該当者のみ）
  合計所得金額:       ○○○,○○○円

■ 所得控除
  社会保険料控除:     ○○○,○○○円
  生命保険料控除:      ○○,○○○円
  基礎控除:           480,000円
  [その他の控除...]
  所得控除合計:       ○○○,○○○円

■ 税額計算
  課税所得金額:       ○○○,○○○円
  算出税額:           ○○○,○○○円
  税額控除:            ○○,○○○円
  復興特別所得税:       ○,○○○円
  所得税及び復興特別所得税: ○○○,○○○円
  源泉徴収税額:       ○○○,○○○円
  予定納税額:          ○○,○○○円
  ---------------------------------
  申告納税額:          ○○,○○○円（納付 / 還付）

■ 次のステップ:
  → /consumption-tax で消費税の計算を行う
  → /e-tax で確定申告書等作成コーナーに入力する（Claude in Chrome）
  → /submit で提出準備を行う
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
