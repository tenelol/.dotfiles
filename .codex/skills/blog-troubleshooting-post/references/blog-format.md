# Blog Format Reference

## Project

- Root: `/Users/tener/projects/blog`
- Engine: Hugo with Blowfish-style content organization
- Post path: `content/posts/<slug>/index.md`
- Default archetype: `archetypes/posts.md`

## Front Matter

Use TOML front matter:

```toml
+++
title = "日本語タイトル"
date = 2026-05-26T18:00:00+09:00
draft = true
summary = "一覧で読める短い要約。"
description = "検索や共有向けの説明。summary と同じでもよいが、少し具体化する。"
tags = ["Neovim", "SKK", "macOS"]
categories = ["Blog"]
+++
```

Existing posts sometimes omit `description`, but new troubleshooting drafts should include it when a natural sentence can be written.

## Current Style

- Japanese prose.
- Short paragraphs.
- Technical terms are left as-is: `Neovim`, `Hugo`, `NixOS`, `Cloudflare Tunnel`.
- Lists are used for concrete points, not for every paragraph.
- The blog is comfortable with personal work logs and decision notes.
- Avoid excessive marketing tone. A troubleshooting post should read like a clear postmortem.

## Good Troubleshooting Shape

```markdown
## 背景

Why this setup or change was attempted.

## 何が起きたか

User-visible symptoms. Include exact keybindings, tools, and error classes when useful.

## 原因

The smallest technical explanation that makes the failure understandable.

## 対応

What changed. Mention important files or commands, but do not paste huge diffs.

## 学び

What to avoid next time. Keep this practical.

## まとめ

One short closing paragraph.
```

## Validation

Prefer:

```sh
nix develop -c hugo --buildDrafts
```

If the Nix shell is unavailable, use:

```sh
hugo --buildDrafts
```

If validation cannot run, state why and still leave the draft in a coherent state.
