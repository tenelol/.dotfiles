# Anything Frontend Art Direction

[日本語](README.md) · [English](README.en.md) · **简体中文** · [한국어](README.ko.md)

Anything Frontend Art Direction 是一个日语前端设计技能，帮助你根据项目题材选择配色、字体、留白和构图。你可以对照作品与设计者本人的说明，判断哪些做法适合自己的页面。遇到实现或评审问题时，也可以通过涵盖 12 个领域、共 1,464 个条目的索引查阅规范和研究原文。

## 与 Motion Atlas 配合使用的示例：DEAD AIR FM

[**在浏览器中打开 DEAD AIR FM**](https://rna4219.github.io/anything-frontend-art-direction/examples/dead-air-fm/)

[![DEAD AIR FM 页面。右侧是戴耳机的 DJ，左侧是粉色台名和青色播放按钮。](docs/dead-air-fm.webp)](https://rna4219.github.io/anything-frontend-art-direction/examples/dead-air-fm/)

DEAD AIR FM 是一个虚构的海盗电台，故事发生在深夜的东京。我们用 Anything Frontend Art Direction 从插画中选取界面用色。台名用了耳机线的粉色，播放按钮则用了 DJ 夹克上的青色。换台时，屏幕上的数字先快速跳动，随后显示新电台的频率。这段动效使用了 [Motion Atlas](https://github.com/RNA4219/motion-atlas)。

点击 **“周波数を選ぶ”（选择频率）** 下方的任一电台，就能收听该频道。**三首曲目均由 YuE2 生成。** 87.9 MHz 播放暗黑电子乐（dark electro），92.4 MHz 播放氛围 dub（ambient dub），98.6 MHz 播放碎拍（breakbeat）。插画、音频和字体都嵌在一个 HTML 文件里，保存后可以离线收听。[下载独立 HTML 文件](https://github.com/RNA4219/anything-frontend-art-direction/raw/refs/heads/main/examples/dead-air-fm/index.html) · [查看 HTML 源码](examples/dead-air-fm/index.html)

## 示例：潮待电影节

[**在浏览器中打开潮待电影节**](https://rna4219.github.io/anything-frontend-art-direction/examples/shiomachi-film/)

![潮待电影节桌面页面。黄昏的港口上叠着白色明朝体标题，下方列出日期、地点，并提供放映日程入口。](docs/shiomachi-film.png)

潮待电影节（潮待ち映画祭）是一个设在港口的虚构露天电影节。日文标题采用粗字重的 Shippori Mincho B1（しっぽり明朝B1），英文副标题采用 Cormorant Garamond 斜体。在放映日程中选一天，就能看到当天放映的两部影片。开场时间用 Noto Sans JP，旁边的片名用明朝体。

[下载电影节的 HTML 文件](https://github.com/RNA4219/anything-frontend-art-direction/raw/refs/heads/main/examples/shiomachi-film/index.html)后，用浏览器打开即可。桌面和手机所用的图片、字体、CSS 和 JavaScript 都在同一个文件里。离线也能切换日期、展开或收起影片简介。[查看 HTML 源码](examples/shiomachi-film/index.html)

## 使用方法

1. [下载 ZIP 并解压](https://github.com/RNA4219/anything-frontend-art-direction/archive/refs/heads/main.zip)，或运行 `git clone https://github.com/RNA4219/anything-frontend-art-direction.git`。
2. 如果下载的是 ZIP，请将解压后的文件夹改名为 `anything-frontend-art-direction`。将文件夹放入所用工具的技能目录，使用说明见 [SKILL.md](SKILL.md)。
3. 可以这样提出需求：“用 anything-frontend-art-direction 为港口露天电影节设计一个页面。用实际的电影节名称比较两种字体，让观众在手机上也能轻松找到放映时间。”

参考资料为日语，可以直接阅读 Markdown。各条目附有原始发布页面的链接，可查看作品图片和资料原文。

| 想了解什么 | 参考资料 |
| --- | --- |
| 寻找贴合题材的案例，选择配色、字体和构图 | [设计步骤](references/visual-direction.md) · [构图与手机布局](references/visual-composition.md) · [字体与色彩](references/visual-craft.md) |
| 查找百货商店、游戏等商业设计案例 | [全球 247 个作品与资料条目](references/design-works.md) |
| 了解字体在具体场景中的用法，以及设计者如何解释选择 | [字体调查数据及阅读指南](data/typography/README.md) |
| 复现页面实现中的问题 | [11 种 HTML 模板](templates/README.md) · [12 个领域的索引](SKILL.md) · [来源列表](sources.md) |
| 评审页面 | [无障碍](checklists/accessibility.md) · [表单](checklists/forms.md) · [动效](checklists/motion.md) · [性能](checklists/performance.md) |

字体调查共收录 247 件作品，整理出 292 条记录，有 CSV 和 SQLite 两种格式。其中有 46 件作品，我们还对照设计者的说明，逐一查看了字形、字号和排布。

## 许可证

本仓库编写的说明、调查数据的文字描述与编排、模板，以及为示例创作的代码、图片和音频均按 [MIT 许可证](LICENSE) 分发。

示例中嵌入的字体采用 **SIL Open Font License 1.1**。每个示例的 HTML 中都包含 MIT 版权和许可声明，以及所用字体的版权声明和许可证全文。使用链接指向的第三方作品或资料时，请查阅原发布方的使用条款。[随附内容的来源与许可证](NOTICE.md)
