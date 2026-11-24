# Anything Frontend Art Direction

[日本語](README.md) · **English** · [简体中文](README.zh-CN.md) · [한국어](README.ko.md)

Anything Frontend Art Direction is a Japanese-language frontend design skill for choosing a color palette, typefaces, spacing, and composition to suit a project. Look at each design alongside the designer’s explanation to decide what might work on your own page. When you build or review a page, you can use the index to find the original specifications and research. Its 1,464 entries are grouped into 12 topics.

## DEAD AIR FM, built with Motion Atlas

[**Open DEAD AIR FM in your browser**](https://rna4219.github.io/anything-frontend-art-direction/examples/dead-air-fm/)

[![DEAD AIR FM with a headphone-wearing DJ on the right and the station name in pink above a cyan play button on the left.](docs/dead-air-fm.webp)](https://rna4219.github.io/anything-frontend-art-direction/examples/dead-air-fm/)

DEAD AIR FM is a fictional pirate radio station broadcasting after dark in Tokyo. We used Anything Frontend Art Direction to choose colors from the illustration. The station name takes its pink from the headphone cable, and the play button takes its cyan from the DJ’s jacket. When you tune in to another station, the digits briefly scramble before the dial shows the new frequency. We built that effect with [Motion Atlas](https://github.com/RNA4219/motion-atlas).

Choose a station under **周波数を選ぶ** (“Choose a frequency”) to start listening. **All three tracks were generated with YuE2.** Tune to 87.9 MHz for dark electro, 92.4 MHz for ambient dub, or 98.6 MHz for breakbeat. The illustration, recordings, and fonts are embedded in a single HTML file, so you can save it and listen offline. [Download the standalone HTML](https://github.com/RNA4219/anything-frontend-art-direction/raw/refs/heads/main/examples/dead-air-fm/index.html) · [View the HTML source](examples/dead-air-fm/index.html)

## Shiomachi Film Festival

[**Open the film festival in your browser**](https://rna4219.github.io/anything-frontend-art-direction/examples/shiomachi-film/)

![Desktop view of the Shiomachi Film Festival. A large white Mincho title sits over a harbor at dusk, with dates, venue details, and a link to the screening schedule below.](docs/shiomachi-film.png)

Shiomachi Film Festival (潮待ち映画祭) is a fictional outdoor festival set in a harbor. The Japanese title uses a bold weight of Shippori Mincho B1, paired with Cormorant Garamond italic for the English subtitle. Select a date in the schedule to see that day’s two films. Start times are set in Noto Sans JP, with the film titles beside them in Mincho.

[Download the festival HTML](https://github.com/RNA4219/anything-frontend-art-direction/raw/refs/heads/main/examples/shiomachi-film/index.html) and open it in a browser. It includes the desktop and mobile images, fonts, CSS, and JavaScript in one file. You can switch dates and expand or collapse each synopsis offline. [View the HTML source](examples/shiomachi-film/index.html)

## Use the skill

1. [Download and extract the ZIP](https://github.com/RNA4219/anything-frontend-art-direction/archive/refs/heads/main.zip), or run `git clone https://github.com/RNA4219/anything-frontend-art-direction.git`.
2. If you used the ZIP, rename the extracted folder to `anything-frontend-art-direction`. Place the folder in your tool’s skills directory. The instructions are in [SKILL.md](SKILL.md).
3. Try a request such as “Use anything-frontend-art-direction to build a page for an outdoor film festival at a harbor. Show me two typefaces using the actual festival name, and make screening times easy to find on a phone.”

You can read the Japanese reference material directly in Markdown. The links lead to images of the work and source documents on the publishers’ own sites.

| What you want to do | Where to look |
| --- | --- |
| Find relevant examples and choose colors, type, and composition | [Design process](references/visual-direction.md) · [Composition and mobile layouts](references/visual-composition.md) · [Type and color](references/visual-craft.md) |
| Explore department store, game, and other commercial design | [247 works and sources from around the world](references/design-works.md) |
| See how type is used in context and how designers explain their choices | [Typography data and reading guide](data/typography/README.md) |
| Reproduce an implementation issue | [11 HTML templates](templates/README.md) · [Index of 12 topics](SKILL.md) · [Source list](sources.md) |
| Review a screen | [Accessibility](checklists/accessibility.md) · [Forms](checklists/forms.md) · [Motion](checklists/motion.md) · [Performance](checklists/performance.md) |

The typography dataset is available in CSV and SQLite and contains 292 records from 247 works. For 46 of those works, we compared the letterforms, sizes, and placement on screen with the designers’ explanations.

## License

The explanations, research descriptions and editorial work, templates, and the code, images, and music created for the examples in this repository are distributed under the [MIT License](LICENSE).

Fonts embedded in the examples are licensed under the **SIL Open Font License 1.1**. Each example’s HTML includes the MIT copyright and permission notice, plus the copyright notices and full license text for its fonts. For third-party works and materials linked from the repository, consult the terms at the source. [Credits and licenses for bundled materials](NOTICE.md)
