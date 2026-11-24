# Anything Frontend Art Direction

**日本語** · [English](README.en.md) · [简体中文](README.zh-CN.md) · [한국어](README.ko.md)

Anything Frontend Art Direction は、題材に合う配色・書体・余白・構図を選ぶための日本語のフロントエンドデザインスキルです。作品と制作者の解説を見比べながら、自分の画面に取り入れたい工夫を探せます。実装やレビューで迷ったときは、12分野・1,464項目の索引から仕様や研究の原文をたどれます。

## Motion Atlas との併用作例「DEAD AIR FM」

[**DEAD AIR FM をブラウザーで開く**](https://rna4219.github.io/anything-frontend-art-direction/examples/dead-air-fm/)

[![DEAD AIR FMの画面。右にヘッドホンのDJ、左にピンクの局名とシアンの再生ボタン。](docs/dead-air-fm.webp)](https://rna4219.github.io/anything-frontend-art-direction/examples/dead-air-fm/)

DEAD AIR FM は、東京の深夜を舞台にした架空の海賊ラジオ局です。Anything Frontend Art Direction で、イラストをもとに画面の配色を決めました。局名にはヘッドホンのコードと同じピンクを、再生ボタンにはDJのジャケットと同じシアンを使っています。選局すると、数字が一瞬乱れたあと、選んだ局の周波数が表示されます。この演出には [Motion Atlas](https://github.com/RNA4219/motion-atlas) を使いました。

「周波数を選ぶ」で局を押すと、その場で曲が流れます。**3局の曲はすべて YuE2 で生成しました。** 87.9 MHz はダークエレクトロ、92.4 MHz はアンビエントダブ、98.6 MHz はブレイクビーツです。イラスト、音源、フォントを1枚のHTMLに収めているので、保存してオフラインでも聴けます。[単体HTMLをダウンロード](https://github.com/RNA4219/anything-frontend-art-direction/raw/refs/heads/main/examples/dead-air-fm/index.html)・[HTMLのソース](examples/dead-air-fm/index.html)

## 作例「潮待ち映画祭」

[**潮待ち映画祭をブラウザーで開く**](https://rna4219.github.io/anything-frontend-art-direction/examples/shiomachi-film/)

![潮待ち映画祭のPC画面。夕暮れの港を背景に、白い明朝体で映画祭名を大きく表示。下部に会期と会場、上映日程へのリンクが並ぶ。](docs/shiomachi-film.png)

「潮待ち映画祭」は港で開く架空の野外映画祭です。映画祭名には太い「しっぽり明朝B1」を、欧文の副題には Cormorant Garamond のイタリックを使いました。上映表で日付を選ぶと、その日の2作品を確認できます。開始時刻は Noto Sans JP、隣に並ぶ作品名は明朝体です。

[作例のHTMLをダウンロード](https://github.com/RNA4219/anything-frontend-art-direction/raw/refs/heads/main/examples/shiomachi-film/index.html)して、ブラウザーで開いてください。PC用とスマホ用の画像、書体、CSS、JavaScriptをすべて1枚のHTMLに収めました。オフラインでも上映日を切り替えたり、各作品のあらすじを開いたり閉じたりできます。[HTMLのソース](examples/shiomachi-film/index.html)

## スキルを使う

1. [ZIPをダウンロード](https://github.com/RNA4219/anything-frontend-art-direction/archive/refs/heads/main.zip)して展開するか、`git clone https://github.com/RNA4219/anything-frontend-art-direction.git` を実行します。
2. ZIPを展開したら、フォルダの名前を `anything-frontend-art-direction` にします。どちらの方法でも、このフォルダをお使いのツールのスキルディレクトリに置きます。スキルの使い方は [SKILL.md](SKILL.md) にあります。
3. たとえば「anything-frontend-art-direction を使って港の野外映画祭のページを作って。映画祭名の書体を2案、実際の題名で比べて。スマホでも上映時刻を探せるようにして」と依頼します。

資料はMarkdownとして直接読めます。各項目のリンクを開くと、作品の画像や資料の原文を公開元で確認できます。

| 調べたいこと | 参照先 |
| --- | --- |
| 題材に合う見本を探し、配色・文字・構図を選ぶ | [制作手順](references/visual-direction.md)・[構図とスマホでの再配置](references/visual-composition.md)・[文字と色の表現](references/visual-craft.md) |
| 百貨店・ゲーム・商業デザインなどの制作例を探す | [世界の作品・資料247件](references/design-works.md) |
| どの場面で文字をどう使い、制作側がその理由をどう説明したか調べる | [書体の調査データと読み方](data/typography/README.md) |
| 実装上の問題を再現して確かめる | [11種類のHTMLテンプレート](templates/README.md)・[12分野の索引](SKILL.md)・[出典一覧](sources.md) |
| 画面をレビューする | [アクセシビリティ](checklists/accessibility.md)・[フォーム](checklists/forms.md)・[モーション](checklists/motion.md)・[性能](checklists/performance.md) |

247作品から集めた書体の調査記録292件を、CSVとSQLiteで読めます。うち46作品では文字の形や大きさ、配置などの工夫を確かめ、制作側が述べた理由と照合しました。

## ライセンス

このリポジトリで作成した解説、調査データの記述と編集内容、テンプレート、作例のコード、画像、音源は [MIT License](LICENSE) で配布します。

各作例に埋め込んだ書体には **SIL Open Font License 1.1** が適用されます。作例のHTMLにはMITの著作権表示と許諾文のほか、各書体の著作権表示とライセンス全文も収めています。リンクで紹介している第三者の作品や資料を使うときは、各公開元の利用条件を確認してください。[同梱物とライセンスの内訳](NOTICE.md)
