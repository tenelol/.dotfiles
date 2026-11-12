# Codex のスキル重複の除外

dotfiles の中で Codex を起動すると、repository の `.agents/skills/` と、ホームに配置した同じスキルの両方が見える。Codex のユーザー設定で repository 側の `SKILL.md` を無効にし、ホーム側を使う。この除外は repository の管理外にある。

## 経緯・判断・理由

- 2026-09-13、codex-cli 0.154.0 では、project 設定の `skills.config` は読み込まれるのに、スキル一覧と prompt 入力には反映されなかった。指定にはフォルダではなく `SKILL.md` の完全なパスが必要だった。
- 本人の承認を得て、ユーザー設定（`$CODEX_HOME/config.toml`）の `[[skills.config]]` で repository 側の `SKILL.md` を `enabled = false` にした。効かない project 設定は残していない。
- 原因は特定していない。他の版に一般化しない。

## 現状

- ホームへの配置は `modules/codex-skills` が行う。除外の一覧はユーザー設定にだけある。
- 除外は書いた時点のスキルに対するもので、その後に増えた repository 側のスキルには追従していない。repository 外のスキル（ChatGPT.app に同梱の hatch-pet）の除外も同じ場所にある。

## 確かめ方

件数は変わるので、その都度数える。

- 除外の件数: `grep -c '^\[\[skills.config\]\]' "$CODEX_HOME/config.toml"`
- repository 側の件数: `find .agents/skills -maxdepth 2 -name SKILL.md | wc -l`
- 除外されていない repository 側のスキル: 除外の `path` に出てくる名前と `.agents/skills/` の名前を突き合わせる。
- 効いているかは、設定の読込（`config/read`）ではなく、dotfiles の中と外の両方で、スキル一覧と `codex debug prompt-input` に同じスキルが1件だけ載るかで確かめる。

## 未解決

- 除外に入っていない repository 側のスキルが、現在の Codex で実際に重複して見えるか（0.154.0 の後は試していない）。
- Codex を更新したら project 設定の `skills.config` が効くようになったかを試す。効くなら、除外を repository で管理できる project 設定へ移すことを検討する。
