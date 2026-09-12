# 作成コーナーへのアクセス・決算書・所得税の入力

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## ステップ1: 確定申告書等作成コーナーへのアクセス

### 開始URL

**https://www.keisan.nta.go.jp/kyoutu/ky/sm/top_web#bsctrl**

### CC-AA-010: 税務署への提出方法の選択

画面番号: CC-AA-010

1. 「マイナンバーカードをお持ちですか」→ **「はい」** ラジオボタンをクリック
2. 「マイナンバーカード読み取りに対応したスマートフォン又はICカードリーダライタをお持ちですか」→ **「はい」** をクリック
3. **「スマートフォンを使用する」** をクリック
   - JS: `doSubmitCSW0100('1','3','/ky/sm/csw0100_myno_qr')`

### CC-AE-090: 作成する申告書等の選択

画面番号: CC-AE-090

選択肢（令和7年分）:
- **所得税** → `doSubmitCMW0900(1,'25')`
- **決算書・収支内訳書（＋所得税）** → `doSubmitCMW0900(2,'25')` ← 事業所得ありの場合
- **消費税** → `doSubmitCMW0900(3,'25')`
- **贈与税** → `doSubmitCMW0900(4,'25')`

**判断基準**:
- 事業所得あり → 「決算書・収支内訳書（＋所得税）」
- 事業所得なし（給与のみ等）→ 「所得税」
- 消費税は所得税完了後に別途作成

### CC-AE-600: マイナポータル連携の選択

→ **「マイナポータル連携を利用しない」** をクリック

### CC-AA-024: e-Taxを行う前の確認

→ **「利用規約に同意して次へ」** をクリック

※ 環境チェック `termnalInfomationCheckOS_myNumberLinkage()` が実行される。
Windows/macOS の Chrome/Edge であれば問題なし。

### CC-AA-440: QRコード認証

**★ ユーザー操作待ち — ブラウザ操作を一時停止**

この画面ではエージェントがブラウザを操作してはならない。
**AskUserQuestion ツールで一時停止**し、ユーザーが認証完了を報告するまで**絶対に次のステップに進まない**こと。

AskUserQuestion で以下を表示する:

```
QRコード認証画面が表示されました。
スマートフォンのマイナポータルアプリでQRコードを読み取り、
マイナンバーカードで認証してください。

認証が完了したら「認証完了」を選択してください。
```

- 選択肢: 「認証完了」 / 「QRコードが表示されない」
- 「QRコードが表示されない」が選ばれた場合は下記の ⚠️ Playwright CLI 使用時の注意 を参照して対処する
- **ユーザーが「認証完了」を選択するまで、一切のブラウザ操作・画面遷移を行わない**

認証完了後、自動的に次の画面に遷移する。

**⚠️ Playwright CLI 使用時の注意**: `PLAYWRIGHT_MCP_INIT_SCRIPT` 環境変数で `etax-stealth.js` を指定することで
サーバーベイク関数パッチが自動適用されるが、QR コードが表示されない場合はコンソールで `getClientOS()` の
戻り値を確認し、`'Windows'` でなければ以下を手動実行する:
```javascript
window.getClientOS = function() { return 'Windows'; };
displayQrcode();
```

---

## ステップ2: 青色申告決算書の入力（事業所得がある場合）

> ⚠️ **ネイティブダイアログ注意**: 「次へ」クリック後に画面が遷移しない場合、ネイティブダイアログ（alert/confirm）が表示されている可能性がある。技術的な知見の「ネイティブダイアログの検知と対処」を参照。

### /kessan/ac/pre/ac0300: 決算書の種類選択

ラジオボタン:
- **青色申告決算書** ← 青色申告の場合
- 収支内訳書（白色申告の場合）
- 青色申告決算書（現金主義用）

### /kessan/ac/aa0200: 損益計算書（P/L）の入力

URL: `https://www.keisan.nta.go.jp/kessan/ac/aa0200#bsctrl`

#### 期間の入力

| フィールド | name | デフォルト |
|-----------|------|-----------|
| 開始月 | `sonekiKeisansyoFromMonth` | 1 |
| 開始日 | `sonekiKeisansyoFromDay` | 1 |
| 終了月 | `sonekiKeisansyoToMonth` | 12 |
| 終了日 | `sonekiKeisansyoToDay` | 31 |

#### 売上（収入）金額

「入力」ボタン → `/kessan/ac/aa0201` 売上仕入月別入力サブページに遷移。

aa0201 のフィールド:
- `uriageKingaku1`〜`uriageKingaku12`: 月別売上
- `siireKingaku1`〜`siireKingaku12`: 月別仕入
- `kajisyohi`: 家事消費等
- `zatusyunyu`: 雑収入

合計: `uriageKingakuGokei`, `siireKingakuGokei`

#### 経費（行8〜31）

| 行 | 科目 | name（直接入力） | 備考 |
|----|------|-------------------|------|
| 8 | 租税公課 | `sozeiKoka` | |
| 9 | 荷造運賃 | `nidukuriUntin` | |
| 10 | 水道光熱費 | `suidoKonetuhi` | |
| 11 | 旅費交通費 | `ryohiKotuhi` | |
| 12 | 通信費 | `tusinhi` | |
| 13 | 広告宣伝費 | `kokokuSendenhi` | |
| 14 | 接待交際費 | `settaiKosaihi` | |
| 15 | 損害保険料 | `songaiHokenryo` | |
| 16 | 修繕費 | `syuzenhi` | |
| 17 | 消耗品費 | `syomohinhi` | |
| 18 | 減価償却費 | — | 「入力」→ `/kessan/ac/init/aa0203` |
| 19 | 福利厚生費 | `fukuriKoseihi` | |
| 20 | 給料賃金 | — | 「入力」→ `/kessan/ac/aa0205` |
| 21 | 外注工賃 | `gaichukotin` | |
| 22 | 利子割引料 | — | 「入力」→ `/kessan/ac/aa0206` |
| 23 | 地代家賃 | — | 「入力」→ `/kessan/ac/aa0207` |
| 24 | 貸倒金 | `kasidaorekin` | |
| 25 | 税理士等の報酬 | `keihiNiniKingaku1` | 科目名: `keihiNiniKamoku1` |
| 26 | 震災関連経費 | `keihiNiniKingaku2` | 科目名: `keihiNiniKamoku2` |
| 27-30 | 任意科目 | `keihiNiniKingaku3`〜`6` | 科目名: `keihiNiniKamoku3`〜`6` |
| 31 | 雑費 | `zappi` | |

集計 hidden フィールド: `keihiSannyugakuGokei`, `kyuryoTinginTotalGokei`, `risiWaribikiryoGokei`, `tidaiYatinGokei`

#### 繰戻額等

- `kurimodosiNiniKamoku1`/`kurimodosiNiniKingaku1`
- `kurimodosiNiniKamoku2`/`kurimodosiNiniKingaku2`

#### 専従者給与

- `senjusyaKyuyoTotalGokei` (hidden、「入力」ボタンで別画面)
- `kasidaoreKuriireGokei` (hidden)

#### 計算結果（自動）

- `disp_aoiroKojomaeSyotokuKingaku` = 売上 - 売上原価 - 経費 + 繰戻額 - 専従者給与等

### /kessan/ac/submit/aa0100: 青色申告特別控除

Q&A形式で控除額を選択:

| 選択肢 | value | 条件 |
|--------|-------|------|
| 10万円 | 2 | |
| 55万円 | 3 | |
| 65万円 | 1 | **e-Tax送信が必須**。書面提出ではエラー KS-E10089 |

フィールド: `aoiroTokubetuKojoSentakugaku`

65万円を選択する場合、電子帳簿保存または e-Tax 送信が条件。

> ⚠️ **ネイティブダイアログ注意**: 65万円を選択して次へ進むと、書面提出の場合は **KS-E10089**（e-Tax送信が必要）のネイティブダイアログが表示される。画面が遷移しない場合はダイアログの有無をユーザーに確認すること。

### 貸借対照表（B/S）の入力

URL: `/kessan/ac/preAoiroCalc`

#### 資産の部

配列形式: `sisannobuTaisyohyoDetailDataList[N].kisyuKingaku` / `.kimatuKingaku`

| index | 勘定科目 |
|-------|----------|
| 0 | 現金 |
| 1 | 当座預金 |
| 2 | 定期預金 |
| 3 | その他の預金 |
| 4 | 受取手形 |
| 5 | 売掛金 |
| 6 | 有価証券 |
| 7 | 棚卸資産 |
| 8 | 前払金 |
| 9 | 貸付金 |
| 10 | 建物 |
| 11 | 建物附属設備 |
| 12 | 機械装置 |
| 13 | 車両運搬具 |
| 14 | 工具器具備品 |
| 15 | 土地 |
| 16-23 | 任意科目 |

#### 負債・資本の部

配列形式: `fusainobuTaisyohyoDetailDataList[N].kisyuKingaku` / `.kimatuKingaku`

| index | 勘定科目 |
|-------|----------|
| 0 | 支払手形 |
| 1 | 買掛金 |
| 2 | 借入金 |
| 3 | 未払金 |
| 4 | 前受金 |
| 5 | 預り金 |
| 6 | 貸倒引当金 |
| 7-15 | 任意科目 |
| 16 | 元入金 |
| 17 | 事業主借 |
| 18 | 事業主貸 |
| 19 | 青色申告特別控除前の所得金額（P/Lから自動） |

**重要**: 資産期末合計 = 負債期末合計 が必須（KS-E40003）

> ⚠️ **ネイティブダイアログ注意**: 資産期末合計と負債期末合計が一致しない状態で「次へ」を押すと、**KS-E40003** のネイティブダイアログが表示される。画面が遷移しない場合はダイアログの有無をユーザーに確認すること。

### /kessan/ac/ac0500: 住所・氏名等の入力

| フィールド | name |
|-----------|------|
| 郵便番号 | `jitakuZip` |
| 都道府県 | `jitakuPrefectureId` |
| 市区町村以下 | `jitakuAddress` |
| 事業所住所（該当者） | `jimusyoAddress` |
| 提出先税務署 | `zeimusyoName` |
| 氏名漢字（姓） | `nameKanjiSei` |
| 氏名漢字（名） | `nameKanjiMei` |
| 業種名 | `gyosyuName` |
| 屋号 | `yago` |
| 提出年月日 | `teisyutuYear`/`teisyutuMonth`/`teisyutuDay` |

### 決算書完了 → 所得税コーナーへ

印刷・データ保存画面（`/kessan/ac/submit/ac0600`）の
「所得税の申告書作成はこちら」ボタンで所得税コーナーに遷移（住所氏名引継ぎ）。

> ⚠️ **ネイティブダイアログ注意**: このボタンをクリックすると **KS-W10035**（印刷を確認したか）のネイティブダイアログが表示される場合がある。画面が遷移しない場合はダイアログの有無をユーザーに確認し、「OK」をクリックするよう案内すること。

---

## ステップ3: 所得税の申告書入力

> ⚠️ **ネイティブダイアログ注意**: 「次へ」クリック後に画面が遷移しない場合、ネイティブダイアログ（alert/confirm）が表示されている可能性がある。技術的な知見の「ネイティブダイアログの検知と対処」を参照。

### SS-AA-010a: 申告する所得の選択等

URL: `https://www.keisan.nta.go.jp/r7/syotoku/taM010a40_doInitialDisplay#bbctrl`

#### 生年月日

| フィールド | name |
|-----------|------|
| 年 | `inOutDto.shnkkBirthymdYy` |
| 月 | `inOutDto.shnkkBirthymdMm` |
| 日 | `inOutDto.shnkkBirthymdDd` |

#### 所得種類の選択（チェックボックス）

| 所得 | name | 典型的な選択 |
|------|------|-------------|
| 給与 | `inOutDto.kyuy` | 会社員: checked |
| 事業（営業等） | `inOutDto.jgyoEgyoTo` | 個人事業主: checked |
| 事業（農業） | `inOutDto.jgyoNogyo` | |
| 不動産 | `inOutDto.fdosn` | |
| 雑（業務・その他） | `inOutDto.ztsGyomSnt` | 暗号資産等: checked |
| 公的年金等 | `inOutDto.kotkNnknKgyoNnknEtc` | |
| 退職金 | `inOutDto.tasyku` | |
| 株式等 | `inOutDto.hatoKbshkJyotRsh` | |
| 先物取引 | `inOutDto.skmnTrhk` | |
| 一時 | `inOutDto.ichj` | |

**shinkoku 対象の典型パターン**:
- 会社員＋副業（事業所得）: `kyuy` + `jgyoEgyoTo` + `ztsGyomSnt`（暗号資産あれば）
- 給与所得のみ: `kyuy`

### SS-AA-050: 収入・所得の入力ハブ

選択した所得種類ごとに入力リンクが表示される。各リンクをクリックして個別入力画面へ遷移。

### SS-CA-010: 給与所得の源泉徴収票の入力

> **物理的な源泉徴収票との対応**: 年末調整済みと年末調整未済で**別フォーム・別ラベル体系**。
> 年末調整済み = A〜L（12項目）、年末調整未済 = A〜E（5項目）。
> 物理的な源泉徴収票の「給与所得控除後の金額」「所得控除の額の合計額」欄は、
> 年末調整済みフォームでは入力不要だが、年末調整未済フォームでは B(自動)・C(入力) として存在する。

#### 年末調整済みフォーム

URL: `https://www.keisan.nta.go.jp/r7/syotoku/taS510a10_doAdd_nncyzm#bbctrl`

##### 主要入力フィールド

| ラベル | name | 備考 |
|--------|------|------|
| A: 支払金額 | `inOutDto.shhraKngk` | 必須 |
| B: 源泉徴収税額 | `inOutDto.gnsnTyosyuZegk` | 2段記載時は下段 |
| E: 社会保険料等の金額 | `inOutDto.sykaHknryoToKngk` | |
| K: 支払者の住所 | `inOutDto.shhrasyJysyKysyOrSyzach` | 28文字以内 |
| L: 支払者の氏名又は名称 | `inOutDto.shhrasyNameOrMesyo` | 28文字以内 |

##### ラジオボタン（記載有無の選択）

| フィールド | ラベル | name | 値 |
|-----------|--------|------|-----|
| 控除対象配偶者の記載 | C | `inOutDto.kojyTashoHagsyKsaUm` | 1(あり)/2(なし) |
| 控除対象扶養親族の記載 | D | `inOutDto.kojyTashoFyoShnzkKsaUm` | 1(あり)/2(なし) |
| 生命保険料控除額の記載 | F※ | `inOutDto.semeHknryoKojygkKsaUm` | 1(あり)/2(なし) |
| 地震保険料控除額の記載 | G※ | `inOutDto.jshnHknryoKojygkKsaUm` | 1(あり)/2(なし) |
| 住宅借入金等特別控除額の記載 | H※ | `inOutDto.jyutkKrirknToTkbtsKojyGkKsaUm` | 1(あり)/0(なし) |
| 所得金額調整控除額の記載 | I※ | `inOutDto.sytkKngkTyoseKojygkKsaUm` | 1(あり)/0(なし) |
| 本人が障害者・寡婦等 | J※ | `inOutDto.hnninSygsyKfHtriyKnroGkseKsaUm` | 1(あり)/2(なし) |

> ※ F〜J のラベルはフォーム上の並び順からの推定（スクリーンショット未確認）

##### 条件付きフィールド（ラジオ/チェックで「記載あり」選択時に表示）

| ラベル | name | 表示条件 |
|--------|------|----------|
| B': 源泉徴収税額（内書き） | `inOutDto.gnsnTyosyuZegkUchgk` | チェック時 |
| 社会保険料等（内書き） | `inOutDto.sykaHknryoToUchgk` | チェック時 |
| 生命保険料控除額 | `inOutDto.semeHknryoKojygk` | F「記載あり」時 |
| 新生命保険料金額 | `inOutDto.shnSemeHknryoKngk` | F「記載あり」時 |
| 旧生命保険料金額 | `inOutDto.kyuSemeHknryoKngk` | F「記載あり」時 |
| 介護医療保険料金額 | `inOutDto.kagIryoHknryoKngk` | F「記載あり」時 |
| 新個人年金保険料金額 | `inOutDto.shnKjnNnknHknryoKngk` | F「記載あり」時 |
| 旧個人年金保険料金額 | `inOutDto.kyuKjnNnknHknryoKngk` | F「記載あり」時 |
| 地震保険料控除額 | `inOutDto.jshnHknryoKojygk` | G「記載あり」時 |
| 旧長期損害保険料金額 | `inOutDto.kyuCyokSngaHknryoKngk` | G「記載あり」時 |
| H: 住宅借入金等特別控除額 | `inOutDto.jyutkKrirknToTkbtsKojyGk` | H「記載あり」時 |
| H': 住宅借入金等特別控除可能額 | `inOutDto.jyutkKrirknToTkbtsKojyknoGk` | H「記載あり」時 |
| H'': 住宅借入金年末残高1回目 | `inOutDto.jyutkKrirknToNnmtszndkIkkam` | H「記載あり」時 |
| H''': 住宅借入金年末残高2回目 | `inOutDto.jyutkKrirknToNnmtszndkNkam` | チェック時 |
| 寡婦チェック | `inOutDto.ksaArKforkf` | J「記載あり」時 |
| 勤労学生チェック | `inOutDto.ksaArKnroGkse` | J「記載あり」時 |

#### 年末調整未済フォーム

URL: 要確認

##### 入力フィールド

| ラベル | name | 備考 |
|--------|------|------|
| A: 支払金額 | `inOutDto.shhraKngk` | 必須 |
| B: 給与所得控除後の金額 | （自動計算） | 入力不可。A から自動算出 |
| C: 所得控除の額の合計額 | 要確認 | **入力欄あり。源泉徴収票に記載があれば入力** |
| D: 源泉徴収税額 | `inOutDto.gnsnTyosyuZegk` | |
| E: 住宅借入金等特別控除額 | `inOutDto.jyutkKrirknToTkbtsKojyGk` | |

### SS-AA-070a: 控除の入力（1/2）— 支出系控除

入力リンクのハブ画面。各控除をクリックして個別入力画面に遷移。

対応控除:
- 社会保険料控除（源泉徴収票入力済みの場合「入力あり」表示）
- 小規模企業共済等掛金控除（iDeCo等）
- 生命保険料控除
- 地震保険料控除
- 雑損控除・災害減免
- 医療費控除
- 寄附金控除（ふるさと納税含む — ワンストップ特例分も要入力）

### SS-AA-080: 控除の入力（2/2）— 人的控除・住宅控除等

対応控除:
- 配偶者（特別）控除
- 扶養控除・特定親族特別控除
- 寡婦・ひとり親控除
- 勤労学生控除
- 障害者控除
- 基礎控除（自動計算表示）
- 住宅借入金等特別控除
- 住宅耐震改修特別控除等
- 予定納税額
- 繰越損失額

### SS-AA-090: 計算結果の確認

入力内容から計算された所得税額の確認画面。

表示項目:
- 収入金額・所得金額（所得種類別）
- 所得控除合計
- 課税される所得金額（1,000円未満切捨て）
- 上記に対する税額（速算表適用）
- 差引所得税額
- 復興特別所得税額（基準所得税額の2.1%）
- 所得税及び復興特別所得税の額
- 源泉徴収税額
- 申告納税額（100円未満切捨て）/ 還付される税金

**ここで shinkoku の計算結果と照合する**（後述「ステップ5: 申告内容の確認」参照）。

各セクションに「訂正する」ボタンがあり、前画面に戻れる。

### SS-AC-010a: 納付方法等の入力

納付金額が発生した場合に表示。還付の場合は還付口座入力画面（SS-AB-010a）が表示される。

| フィールド | type | name | 備考 |
|-----------|------|------|------|
| 延納を届け出る | checkbox | — | 利子税がかかる旨の注意あり |
| 納付方法 | select | `inOutDto.nofHoho` | 必須 |

納付方法の選択肢:

| value | 方法 |
|-------|------|
| 1 | 振替納税（期限内申告の場合に利用可） |
| 2 | 電子納税（ダイレクト納付/インターネットバンキング） |
| 3 | クレジットカード納付 |
| 5 | コンビニ納付 |
| 6 | 金融機関等での窓口納付 |

還付の場合は還付口座情報の入力:
- 金融機関名、支店名、口座番号、口座名義

### SS-AC-020a: 財産債務・住民税等

住民税に関する設定（給与からの特別徴収 or 自分で納付 等）。

### SS-AC-030: 基本情報の入力

| ラベル | name | 備考 |
|--------|------|------|
| 氏名フリガナ（姓） | `inOutDto.nameKnSe` | 11文字以内 |
| 氏名フリガナ（名） | `inOutDto.nameKnMe` | |
| 氏名漢字（姓） | `inOutDto.nameKnjSe` | 10文字以内 |
| 氏名漢字（名） | `inOutDto.nameKnjMe` | |
| 電話番号（種別） | `inOutDto.rnrkSkKbn` | 自宅/勤務先/携帯 |
| 電話番号（市外） | `inOutDto.shgaKykbn` | |
| 電話番号（市内） | `inOutDto.shnaKykbn` | |
| 電話番号（番号） | `inOutDto.knyusyBngo` | |
| 納税地区分 | `inOutDto.nozeCh` | 1=住所地, 2=事業所等 |
| 郵便番号 | `inOutDto.yubnBngoGnzaAddress` | 7桁 |
| 都道府県 | `inOutDto.tdofknGnzaAddress` | select |
| 市区町村 | `inOutDto.shkcyosnGnzaAddress` | 都道府県連動 select |
| 丁目番地等 | `inOutDto.cyomBnchToGnzaAddress` | 28文字以内 |
| 建物名 | `inOutDto.ttmnMeGoshtsGnzaAddress` | 28文字以内 |
| 提出先税務署（県） | `inOutDto.tesytSkZemsyTdofkn` | select |
| 提出先税務署 | `inOutDto.tesytSkZemsyZemsy` | 県連動 select |
| 職業 | `inOutDto.job` | 11文字以内 |
| 屋号・雅号 | `inOutDto.ygoGgo` | 30文字以内 |
| 世帯主の氏名 | `inOutDto.stanshNameKnj` | |
| 続柄 | `inOutDto.stanshKrTsdkgr` | select |
| 提出年月日 | `inOutDto.tesytYmdYy`/`Mm`/`Dd` | |

### SS-AC-040: マイナンバーの入力

マイナンバー（12桁）を入力する画面。チェックディジットアルゴリズムによる検証あり。

---
