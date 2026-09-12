# ブラウザ操作の不具合・技術的な注意

この手順内の `scripts/`・`references/`・`research/` は元のスキルルート基準。明示された作業ディレクトリはその指定に従う。

## 技術的な知見

### SPA構造

- jQuery 3 + jQuery UI ベース
- ページ遷移はフォーム POST（`document.forms[formName].submit()`）
- ハッシュ `#bsctrl`（決算書コーナー）/ `#bbctrl`（所得税コーナー）はページ管理用
- `<input type="button">` が多用されており、`id="input_xxx"` で JS `.click()` 操作

### URL体系

| コーナー | URL パターン |
|---------|-------------|
| 共通（認証等） | `/kyoutu/ky/sm/***` |
| 決算書 | `/kessan/ac/***` |
| 所得税 | `/r7/syotoku/***` |
| 消費税（共通） | `/syouhi/ac****` |
| 消費税（2割特例） | `/syouhi/at****` |
| 消費税（一般課税） | `/syouhi/ai****` |
| 消費税（簡易課税） | `/syouhi/ak****` |

### 主要ナビゲーション関数

- `doSubmitCSW0100(qrCodeReadingFlag, reportType, url)` — 認証方法選択
- `doSubmitCMW0900(zeimokuType, year)` — 申告書種類選択（1=所得税, 2=決算書, 3=消費税, 4=贈与税）

### 確認ダイアログ

| コード | 内容 | 対応 |
|--------|------|------|
| KS-W90011 | 入力データが初期化される | OK で続行 |
| KS-W90006 | 入力データをクリアする | OK で続行 |
| KS-W10035 | 印刷を確認したか | OK で続行 |
| KS-E10089 | e-Tax送信が必要（65万円控除） | e-Tax ルートで再実行 |
| KS-E10001 | 必須入力チェック | 入力漏れを修正 |
| KS-E40003 | B/S 資産期末合計 ≠ 負債期末合計 | 金額を修正 |

### 終了ダイアログフロー

消費税コーナー終了時は2段階のダイアログが表示される:
1. `#otherTax` — 「他の申告書等を作成しますか？」
2. `#end` — 「終了してもよろしいですか？」

※ 書面提出選択時はサーベイダイアログが毎回表示される（セッション間で記憶されない）

### ネイティブダイアログの検知と対処

Claude in Chrome は `alert()` / `confirm()` / `prompt()` によるネイティブダイアログを**検知できない**。
ダイアログが表示されている間、ブラウザの DOM 操作はブロックされるため、エージェントの操作が無応答になる。

#### 検知ヒューリスティック

ボタンクリック後に以下の状態が続く場合、ネイティブダイアログが表示されている可能性がある:

- URL が変化しない
- DOM の内容が変化しない（新しい画面に遷移しない）
- ボタンのクリックが何も起こさないように見える

#### 対処手順

1. ダイアログの可能性を検知したら、AskUserQuestion で以下を表示する:

```
ボタンをクリックしましたが、画面が遷移しません。
ブラウザにポップアップ（確認ダイアログ）が表示されていませんか？

表示されている場合は、ダイアログの内容（コード番号がある場合はそれも）を教えてください。
```

- 選択肢: 「ダイアログが表示されている」 / 「ダイアログは表示されていない」

2. ダイアログが表示されている場合:
   - ユーザーにダイアログのメッセージ内容を確認する
   - 既知のコード（上記「確認ダイアログ」テーブルの KS-W*, KS-E* 等）に該当するか照合する
   - KS-W 系（警告）: ユーザーに「OK」をクリックするよう案内
   - KS-E 系（エラー）: エラー内容に応じた修正を案内
   - 不明なダイアログ: ユーザーにメッセージ全文を共有してもらい、対処を判断

3. ダイアログが表示されていない場合:
   - ネットワークエラーやページ読み込み中の可能性を調査する
   - ページの再読み込みを試みる

#### ダイアログが発生しやすい操作

| 操作 | 想定ダイアログ | ステップ |
|------|--------------|---------|
| 「次へ進む」クリック全般 | KS-E10001（必須入力チェック） | 2, 3, 4 |
| 65万円控除の選択 | KS-E10089（e-Tax送信必須） | 2 |
| B/S 入力後の「次へ」 | KS-E40003（資産≠負債） | 2 |
| 決算書完了→所得税遷移 | KS-W10035（印刷確認） | 2→3 |
| 消費税コーナー終了 | `#otherTax` + `#end`（2段階） | 4 |
| データクリア・初期化操作 | KS-W90011, KS-W90006 | 全般 |

### 環境チェック（参考）

確定申告書等作成コーナーの推奨環境:
- Windows 11 + Chrome / Edge
- macOS + Safari

Linux は公式非対応。OS 検出は **2層** で行われるため、回避にも2層の偽装が必要:

1. **クライアントサイド検出**: CC-AA-024 の画面遷移時に `termnalInfomationCheckOS_myNumberLinkage()` が
   `navigator.platform` / `navigator.userAgent` を検査し、Linux 環境では `isTransition=false` となり
   QR コード認証画面（CC-AA-440）への遷移がブロックされる。

2. **サーバーサイド OS ベイク**: サーバーが HTTP リクエストの `User-Agent` / `sec-ch-ua-platform` ヘッダ
   から OS を判定し、レスポンス内の `getClientOS()` 関数に `const os = "Linux"` のようにハードコードする
   （サーバーサイドレンダリング）。`addInitScript` による navigator プロパティ偽装ではこのベイク値は変わらない。
   CC-AA-440 の `displayQrcode()` でも `getClientOS()` が呼ばれ、`oStUseType` を決定する
   （Win=`'3'`, Mac=`'4'`）。Linux だと `undefined` になり QR コードが描画されない。

#### `etax-stealth.js` の2層偽装

`PLAYWRIGHT_MCP_INIT_SCRIPT` 環境変数で `etax-stealth.js` を指定して回避可能:

```bash
PLAYWRIGHT_MCP_INIT_SCRIPT=skills/e-tax/scripts/etax-stealth.js \
  playwright-cli -s=etax open https://www.keisan.nta.go.jp/ --headed --browser=chrome
```

**層 1: navigator プロパティ偽装**（`addInitScript` で実行、ページ読み込み前）

| プロパティ | 偽装値 |
|-----------|--------|
| `navigator.platform` | `'Win32'` |
| `navigator.userAgent` | Windows Chrome 131 UA |
| `navigator.userAgentData` | Windows Chrome Client Hints |
| `navigator.webdriver` | `false` |
| `navigator.plugins` | Chrome 標準プラグイン |
| `navigator.languages` | `['ja', 'en-US', 'en']` |

**層 2: サーバーベイク関数のパッチ**（`DOMContentLoaded` で実行、ページスクリプト後）

| パッチ対象 | 偽装値 | 目的 |
|-----------|--------|------|
| `getClientOS()` | `'Windows'` | サーバーベイク値の上書き |
| `getClientOSVersionAsync()` | `'Windows 11'` | OS バージョン判定の回避 |
| `isRecommendedOsAsEtaxAsync()` | `true` | 推奨 OS 判定の回避 |
| `isRecommendedBrowserAsEtaxAsync()` | `'OK'` | 推奨ブラウザ判定の回避 |

#### トラブルシューティング: QR コードが表示されない

CC-AA-440 で QR コードが表示されない場合、`displayQrcode()` 内で `getClientOS()` が `'Linux'` 等を返し、
`oStUseType` が `undefined` になっている可能性がある。

**確認方法**: ブラウザコンソールで `getClientOS()` の戻り値を確認。`'Windows'` でなければパッチが適用されていない。

**手動対処**（Playwright CLI の場合）:
```bash
playwright-cli -s=etax run-code 'window.getClientOS = function() { return "Windows"; }; displayQrcode();'
```

#### 検証済み画面遷移フロー

CC-AA-010 → CC-AE-090 → CC-AE-600 → CC-AA-024 → CC-AA-440（QR 表示確認済み）

詳細は `docs/wsl-os-detection-workaround.md` を参照。

---
