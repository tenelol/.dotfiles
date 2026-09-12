# 追加のブラウザbackend

現在の環境で直接操作できるブラウザが不足する場合だけ参照する。記載のツールが利用できるとは限らないため、実際のツール一覧とその説明を確認する。子エージェント禁止を別backendで回避しない。

## ブラウザ自動化方式の選択

確定申告書等作成コーナーへの入力には、以下の3つの方式がある。

### 方式 A: Claude in Chrome（その環境で利用可能な場合）

| 項目 | 内容 |
|-----|------|
| 対象環境 | Windows / macOS のネイティブ Chrome |
| 前提 | Claude in Chrome 拡張機能がインストール済み |
| 利点 | OS 検出の問題なし。追加設定不要 |

### 方式 B: Antigravity Browser Sub-Agent

| 項目 | 内容 |
|-----|------|
| 対象環境 | Windows / macOS / Linux（Antigravity IDE） |
| 前提 | Antigravity IDE がインストール済みで `browser_subagent` ツールが利用可能 |
| 利点 | ネイティブ Chrome を使用するため OS 偽装不要。Linux でも動作 |

### 方式 C: Playwright CLI（フォールバック）

| 項目 | 内容 |
|-----|------|
| 対象環境 | WSL / Linux、または Claude in Chrome・Antigravity が利用できない環境 |
| 前提 | `@playwright/cli` + Playwright CLI スキル + `etax-stealth.js`（OS 偽装スクリプト） |
| 制限 | headed モード必須（QR コード認証に物理操作が必要） |

### 判定ロジック

```
1. Claude in Chrome のツール（browser_navigate 等）が利用可能か？
   → はい: 方式 A を使用
   → いいえ: 次へ

2. 委譲が許可され、Antigravity の browser_subagent ツールが利用可能か？
   → はい: 方式 B を使用
   → いいえ: 次へ

3. Bash ツールで `playwright-cli` コマンドが利用可能か？
   → はい: 方式 C を使用（headed モードで起動）
   → いいえ: エラー表示

   エラーメッセージ:
   「確定申告書等作成コーナーへの入力には、Claude in Chrome、
    Antigravity Browser Sub-Agent、または Playwright CLI が必要です。
    セットアップ方法は README.md の『ブラウザ自動化』セクションを参照してください。」
```

### 方式 B 使用時の操作方法

Antigravity の `browser_subagent` は高レベルなタスク記述で操作する。
委譲が許可されている場合だけ各ステップの入力操作を `browser_subagent` に委任する。子を使わない指定がある場合は直接のブラウザ操作を使う。

例:
- 「https://www.keisan.nta.go.jp/kyoutu/ky/sm/top_web#bsctrl を開く」
- 「『マイナンバーカードをお持ちですか』で『はい』のラジオボタンをクリック」
- 「name='sonekiKeisansyoFromMonth' の入力欄に '1' を入力」

※ Antigravity はネイティブ Chrome を使用するため、`etax-stealth.js` による OS 偽装は不要。

### 方式 C 使用時のセッション開始手順

Playwright CLI でブラウザを開く際の手順:

1. 環境変数を設定: `PLAYWRIGHT_MCP_INIT_SCRIPT=skills/e-tax/scripts/etax-stealth.js`
2. ブラウザ起動: `playwright-cli -s=etax open <url> --headed --browser=chrome`
3. 以降のコマンドは `-s=etax` セッション指定で実行
