---
name: blog-troubleshooting-post
description: Use when turning a debugging session, painful troubleshooting story, AI-assisted development failure, dotfiles/Nix incident, or technical worklog into a readable Japanese draft post for the user's Hugo blog at ~/projects/blog.
---

# Blog Troubleshooting Post

## Purpose

Create readable Japanese draft posts for the user's Hugo blog from messy debugging context: what broke, why it broke, what fixed it, and what should be avoided next time.

## Workflow

1. Use the blog root `/Users/tener/projects/blog`.
2. Before editing, inspect the current blog conventions:
   - `AGENTS.md` or `README.md` if present
   - `hugo.toml`, `config/_default/*.toml`, and `archetypes/posts.md`
   - 2-4 recent files under `content/posts/*/index.md`
3. Check `git status --short` in the blog repo. Do not overwrite unrelated user changes.
4. Read [references/blog-format.md](references/blog-format.md) for the current target shape.
5. Draft a new post at `content/posts/<slug>/index.md`.
6. Build or validate with the smallest available blog command. Prefer:
   - `nix develop -c hugo --buildDrafts`
   - fallback: `hugo --buildDrafts`
7. Report the created file, validation result, and any remaining uncertainty.

## Writing Rules

- Write in Japanese.
- Keep the tone practical, candid, and readable. Do not turn the post into a blame log.
- Default to `draft = true` unless the user explicitly asks to publish.
- Prefer short paragraphs and concrete section headings.
- Preserve useful technical specificity: tool names, config filenames, commands, symptoms, and final architecture.
- Remove or generalize secrets, tokens, API keys, passwords, private URLs, exact private logs, and unnecessary personal details.
- If the source context includes a mistake by an AI agent, explain the technical cause and lesson without making the article a complaint.
- If the conversation has enough context, write the article directly. Ask a concise question only when the missing detail blocks a coherent draft.

## Suggested Structure

Use this as a default, then adapt to the actual story:

```markdown
## 背景

## 何が起きたか

## 原因

## 対応

## 学び

## まとめ
```

For long incidents, add `## 時系列` before `## 原因`. For short notes, merge sections rather than padding.

## Slug And Metadata

- Use a short English kebab-case slug, for example `neovim-skk-input-trouble`.
- Use TOML front matter with `+++`.
- Use the current date with timezone offset.
- Use `categories = ["Blog"]` for personal troubleshooting posts.
- Use focused tags such as `["Neovim", "SKK", "macOS", "Nix"]`.
