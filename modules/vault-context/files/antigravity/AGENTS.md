
# Antigravity environment

- 途中経過・計画・artifact・最終回答など、ユーザーに見える出力は日本語で書く。コード・コマンド・識別子・commit messageは既存の規約に従う。
- このMacはaarch64-darwinで、`~/.dotfiles` のnix-darwin・denix・integrated Home Managerで管理している。システム構成を変える前に `~/.dotfiles/AGENTS.md` を読み、永続的なパッケージはdotfiles経由で入れる。
- 対話シェルはFish。対話用のsnippetはFish互換にし、portableなscriptは `#!/usr/bin/env bash` と `set -euo pipefail` で書く。
- skillは `~/.gemini/config/skills/` にあり、Claude Codeと同じ共有skillを指す。context budgetで一覧から説明が省かれたskillも、必要なら `~/.gemini/config/skills/<name>/SKILL.md` を直接読んで使う。ブラウザー作業では `~/.gemini/config/skills/phi-browser/SKILL.md` を読む。
