---
name: find-skills
description: "スキルの検索・比較・インストールを依頼されたときに使う。一般的な使い方の質問には使わない。"
---

# Find Skills

Find a skill when the user asks to extend or inspect available capabilities. Do not turn an ordinary task into a search or installation workflow.

1. Check available skills and tools for the requested capability before looking for another package.
2. Search a specific capability with `npx skills find <query>` or the official source. Use a named owner when requested.
3. Read the candidate's actual instructions, required tools and maintained source. Compare scope, duplication, useful resources and installation side effects. Popularity is supporting context, not a minimum threshold or proof of quality.
4. Present relevant choices with source links and concrete differences. If none fits, continue the original task with available tools.
5. Install only when requested, using the user's chosen location and repository's skill-management convention. An install request does not authorize replacing unrelated skills.

The Skills CLI also supports `npx skills check` and `npx skills update`; an audit does not itself authorize updating every package. For plugin-managed capabilities, use the host's plugin management path so upstream updates remain intact.
