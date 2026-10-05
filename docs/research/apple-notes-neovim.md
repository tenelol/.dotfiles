# Apple標準メモをNeovimで編集する既存手段

2026-10-05 調査。Apple標準メモをNeovimから編集してiCloud同期を保つ方法を、作者のREADME・実装・本人投稿で確認した。ツールの導入と実際のメモの読取・変更は行っていない。

## 結論

**希望に最も近い実装は [`rdrkr/apple-notes.nvim`](https://github.com/rdrkr/apple-notes.nvim)。** メモをMarkdownの仮想bufferとして開き、通常の`:w`で標準メモへ書き戻す。READMEだけでなく、`BufWriteCmd`→保存queue→PandocでHTML変換→AppleScriptの`set body`という処理を確認した。[bufferの保存処理](https://github.com/rdrkr/apple-notes.nvim/blob/e78bf81358be75dd353b7e96125f3d39d42e7fee/lua/apple-notes/buffer.lua#L230-L281)、[保存queue](https://github.com/rdrkr/apple-notes.nvim/blob/e78bf81358be75dd353b7e96125f3d39d42e7fee/lua/apple-notes/sync.lua#L101-L187)、[AppleScript書込](https://github.com/rdrkr/apple-notes.nvim/blob/e78bf81358be75dd353b7e96125f3d39d42e7fee/lua/apple-notes/applescript.lua#L53-L84)。

その後のiCloud同期はApple側に任せる構成。AppleはiCloudのメモに対する編集が他デバイスにも自動表示されると説明している。この仕様と上記コードから、iCloudアカウント内のメモなら要件に合う経路と判断できるが、このMacでの`:w`→iCloud→他端末の実動作は未検証。[Appleの同期仕様](https://support.apple.com/ja-jp/guide/icloud/mm2d069f7097/icloud)、[iCloudの設定と対象フォルダ](https://support.apple.com/ja-jp/guide/icloud/mm8685520792/icloud)。

## 候補比較

| 手段 | 標準メモへ反映する操作 | 主な条件・制約 |
| --- | --- | --- |
| [`apple-notes.nvim`](https://github.com/rdrkr/apple-notes.nvim) | Neovimでメモを開き、`:w`でAppleScriptを通して更新 | macOS 14+、Neovim 0.10+、Pandoc 3+。フルディスクアクセスが必要。公開履歴は2 commitで、実機未検証。[README](https://github.com/rdrkr/apple-notes.nvim/blob/e78bf81358be75dd353b7e96125f3d39d42e7fee/README.md) |
| [`antoniorodr/memo`](https://github.com/antoniorodr/memo) | `EDITOR=nvim`で`memo notes -e`。エディタ終了後に書き戻すので、`:w`単独では反映しない | macOS用CLI。READMEは開発中と明記。画像はプレースホルダーで保持するが、再添付後は末尾へ移る。[README](https://github.com/antoniorodr/memo/blob/5989e950b994c92b2e61bbae591f3f87fadf5073/README.md)、[実装](https://github.com/antoniorodr/memo/blob/5989e950b994c92b2e61bbae591f3f87fadf5073/src/memo_helpers/edit_memo.py#L89-L127) |
| [`coddingtonbear/icloud-md`](https://github.com/coddingtonbear/icloud-md) | Apple Notesを`.md`ファイルへ取得し、任意のエディタで編集して`push`。他端末の変更は`pull`で取得 | macOS/Linux/Windows、Node 20+。継続・自動同期は提供しない。非公開CloudKitの解析を利用し、作者はデータ損失の可能性を明記。[README](https://github.com/coddingtonbear/icloud-md/blob/e6b6f592c334cdf821aaca07da8a71c97273ece9/README.md) |
| [`tonisives/ovim`](https://github.com/tonisives/ovim) | 標準メモの入力欄から本物のNeovimを開き、`:wq`でテキストを貼り戻す | macOS 10.15+、Accessibility許可が必要。GUIの入力欄を編集する方式。[README](https://github.com/tonisives/ovim#edit-popup)、[Notes対応を記した作者投稿](https://www.reddit.com/r/neovim/comments/1pqks2r/edit_any_macos_text_field_in_neovim_with_a/) |

## apple-notes.nvimの確認範囲

一覧等は`sqlite3 -readonly`でローカルDBを読み、本文の取得・書込はAppleScriptを使う。保存は非同期で、成功callbackでbufferのmodified flagを下げる。外部変更の検出は既定30秒のpollとbuffer/focusイベントで行い、再読込・自分の内容を維持・差分表示を選ばせる。[DB読取](https://github.com/rdrkr/apple-notes.nvim/blob/e78bf81358be75dd353b7e96125f3d39d42e7fee/lua/apple-notes/db.lua#L217-L237)、[本文取得](https://github.com/rdrkr/apple-notes.nvim/blob/e78bf81358be75dd353b7e96125f3d39d42e7fee/lua/apple-notes/applescript.lua#L30-L51)、[変更検出](https://github.com/rdrkr/apple-notes.nvim/blob/e78bf81358be75dd353b7e96125f3d39d42e7fee/lua/apple-notes/sync.lua#L189-L241)。

GitHub APIで2026-03-23作成、03-24最終push、2 commitを確認した。コード確認と実際の安定性は分けて扱う。画像は書込時に除外する実装があり、画像・表・チェックリスト・特殊な書式を含む既存メモの完全な往復保持は未確認。導入するなら本文だけのテストメモで、保存完了表示と他端末への反映を確かめるのが適切。[repository metadata](https://api.github.com/repos/rdrkr/apple-notes.nvim)、[画像を除外する変換処理](https://github.com/rdrkr/apple-notes.nvim/blob/e78bf81358be75dd353b7e96125f3d39d42e7fee/lua/apple-notes/converter.lua#L427-L454)。

ローカルにあるApple提供の`/System/Applications/Notes.app/Contents/Resources/Notes.sdef`もread-onlyで確認した。`body`はHTMLの書込可能property、`plaintext`はread-only。実際のNotes内容にはアクセスしていない。

## icloud-mdの位置づけ

調査時のHEADは`e6b6f592c334cdf821aaca07da8a71c97273ece9`、`package.json`はv0.6.2。通常のMarkdownファイルとして編集する要求には近いが、作者はリアルタイム・継続同期を明確に対象外としている。CLIのコマンド定義にもwatch/daemonはない。Neovim保存時の自動送信には別の連携が必要になる。[README](https://github.com/coddingtonbear/icloud-md/blob/e6b6f592c334cdf821aaca07da8a71c97273ece9/README.md#non-goals)、[CLI実装](https://github.com/coddingtonbear/icloud-md/blob/e6b6f592c334cdf821aaca07da8a71c97273ece9/src/cli.ts)、[version](https://github.com/coddingtonbear/icloud-md/blob/e6b6f592c334cdf821aaca07da8a71c97273ece9/package.json)。

非tableの添付があるメモは全体が書込不可。作者は高度なデータ保護（ADP）が有効なアカウントでは利用できない可能性を記し、独立したバックアップとテストメモでの確認を求めている。[制約と注意事項](https://github.com/coddingtonbear/icloud-md#known-limitations)。同じ作者の[Obsidianプラグイン](https://github.com/coddingtonbear/obsidian-apple-notes)は任意の間隔でpull→pushを行い、実行をqueueで直列化する。これは自動化の実例だがNeovim用ではない。

## 実際に取り組んでいる人

- `ovim`作者は、Notesを含むmacOS入力欄を自分のNeovim環境で編集して貼り戻せると[本人投稿](https://www.reddit.com/r/neovim/comments/1pqks2r/edit_any_macos_text_field_in_neovim_with_a/)で説明している。第三者による独立検証とは区別する。
- `memo`作者は[2025年の紹介投稿](https://www.reddit.com/r/Python/comments/1jspmga/memo_manage_your_apple_notes_and_reminders_from/)で、自分もNeovimを使うと返信している。これだけでNeovim専用プラグインの存在や安定性までは言えない。
- `icloud-md`作者は、Apple Notesで共同作業しながらPCではMarkdownエディタで書きたいという動機と、`vim`で編集してpushする例を[本人投稿](https://www.reddit.com/r/Markdown/comments/1vtmlnw/your_apple_notes_now_editable_as_plain_markdown/)に記している。

未確認事項は、各ツールの現行macOSへの適合、テキスト以外の内容の保持、保存直後の終了操作、実際の他端末同期と競合時の挙動。今回の調査結果は導入候補の選定までとし、インストールや本番メモの変更は行っていない。
