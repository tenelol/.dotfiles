---
name: windows-via-crd
description: MacからChrome Remote Desktopで個人Windows PC「Tener」へ接続し、Windows GUI、Windows Codex、Desktop VPNなどの作業を安全に実行する。ユーザーが「Windowsで作業して」「Tenerへ接続して」「Chrome Remote Desktopで操作して」「Windows経由でDesktop VPNを使って」などと依頼したときに使用する。
---

# Windows via Chrome Remote Desktop

Macから個人Windows PC `Tener` へ接続し、依頼されたWindows作業を完了する。CRD PINはmacOSキーチェーンだけに保存し、Codexの出力、ログ、Vault、Gitへ残さない。

## 接続情報

- CRD URL: `https://remotedesktop.google.com/access`
- 接続先名: `Tener`
- Keychain service: `dev.tener.codex.crd.Tener.pin`
- PIN helper: `scripts/crd-pin-keychain.sh`
- 主モニター: `JAPANNEXT MNT`
- 副モニター: `LCD-GC243HXD`

セッションID付きURLは永続情報として保存しない。アクセス一覧から接続先名 `Tener` を選ぶ。

## PINを準備する

1. `scripts/crd-pin-keychain.sh status` を実行する。
2. `missing` の場合だけ、ユーザーの承認を得て `scripts/crd-pin-keychain.sh store` を実行する。
3. `store` が表示するmacOSの非表示入力ダイアログでは、ユーザー本人にPINを入力してもらう。

PINを引数、環境変数、ファイル、会話へ渡さない。次の操作は禁止する。

- `security find-generic-password -w ...` をパイプなしで実行する
- `pbpaste` やブラウザーのclipboard read APIでPINを読む
- shell tracingを有効にする
- CRDの「このデバイスにPINを保存」を有効にする

## 接続する

1. `chrome:control-chrome` スキルを読み、既存のログイン状態を使ってCRD URLを開く。現在この連携が操作するDiaのタブを使う。
2. `Tener` が「オンライン」であることを確認する。オフラインなら勝手に別ホストへ接続せず、Windowsの電源・ネットワーク・CRD Host状態を確認する。
3. `Tener に接続` を選び、PIN入力画面まで進む。
4. PIN入力欄へフォーカスする。
5. `scripts/crd-pin-keychain.sh enter` を実行する。ヘルパーはセッションURLのDiaタブがちょうど1つあり、フォーカス先がラベル `PIN を入力` のsecure text fieldである場合だけ、Keychainから直接PINを設定する。PINはクリップボードを経由しない。
6. 接続ボタンを押し、画面上の「接続しました」で成功を確認する。

ブラウザー自動操作の仮想クリップボードへPINを設定しない。`enter` に失敗した場合はPINを抽出せずユーザーへ手入力を依頼する。`copy` はユーザー自身が手動貼り付けする場合だけの予備手段とし、自動操作では使わない。

## Windowsを操作する

1. 全画面一覧ではなく対象モニターを1台ずつ選び、視認性を確保する。
2. GUI作業はCRD画面を確認しながら実行する。大きなWindows作業をWindows Codexへ委任するときも、完了状態をCRDで確認する。
3. パスワード、OTP、Desktop VPNのコンピュータIDなどが必要な画面では、ユーザー本人に入力を依頼する。
4. UAC、管理者承認、会社規程に関わる変更は、対象と影響を説明して承認を得てから進める。
5. 会社側PCへCRDを導入しない。ファイアウォール、証明書検証、EDR/AVを回避・無効化しない。

Desktop VPNを使う場合は、`Tener` 上のWindows版クライアントを起動する。接続情報は取得・保存せず、入力画面をユーザーへ引き渡す。

## 終了する

- ユーザーが引き続き操作する場合はCRDタブをhandoff状態で残す。
- 作業終了時は秘密入力欄を閉じ、`scripts/crd-pin-keychain.sh clear` を再実行する。
- 実施内容、未確認事項、再起動試験の有無だけを報告し、資格情報を報告へ含めない。
