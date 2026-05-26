---
name: imoocs
description: Use when working with INIAD MOOCs (moocs.iniad.org), INIAD course pages, lessons, assignments, submissions, attendance, slides, lecture materials, or Google Drive handouts. Always try the local `imoocs` CLI before browser or Playwright workflows, especially when a MOOCs URL is provided.
---

# INIAD MOOCs

## Overview

Use the local `imoocs` command as the first interface for INIAD MOOCs work. In this dotfiles repo, `imoocs` is an agent-safe wrapper around the Rust `collect-cli` from `yu7400ki/moocs-collect`; it enforces JSON envelopes, URL handling, and submission safety rules while delegating supported slide PDF collection to `collect-cli`.

## Core Rules

1. When a `moocs.iniad.org` URL appears, run `imoocs open <url>` first. Do not open a browser or Playwright first.
2. Do not manually parse MOOCs URLs. Treat `imoocs open` as the URL router, even when the backend reports an unsupported envelope.
3. Treat `course`, `lesson`, `assignment`, `slide`, `drive`, and `open` command output as JSON envelopes.
4. Treat `auth *` and `reset` as text output plus exit code, not JSON.
5. Do not search for, print, save, or ask the user to paste passwords, tokens, cookies, or other credentials. Login happens through the CLI prompt in the user's TTY.
6. Assignment submit/upload/push operations require explicit user instruction. Never infer permission from a request to inspect a course or assignment.

## CLI Health

Start by checking availability when it is not already known:

```bash
command -v imoocs
imoocs --help
```

If `imoocs` is missing, stop the MOOCs operation and report that the `imoocs` package is required. Do not silently switch to browser operation.

`collect-cli` is the backend for interactive slide collection. Check it only when diagnosing backend availability:

```bash
command -v collect-cli
collect-cli --help
```

## URLs

```bash
imoocs open 'https://moocs.iniad.org/...'
```

Parse the JSON envelope. If `ok` is false, report the unsupported operation and use the envelope's `data.next` hints where relevant. Do not parse the URL by hand.

## Slides

Use the wrapper for slide PDFs:

```bash
imoocs slide collect --path /path/to/download-dir --year 2025
```

This command requires an interactive TTY. It prompts through `collect-cli` for INIAD username, password, course, lecture, and page, then prints one JSON envelope containing the exit code and newly created PDF paths.

If the user wants to avoid typing or pasting the username in chat, tell them to set `IMOOCS_USERNAME` in their own shell before running `imoocs slide collect`. Do not write the actual username into `SKILL.md`, dotfiles, commands shown in final output, or repo files.

If the user does not specify a download directory, choose a stable local directory for the task and report it.

## Assignments

Only handle assignment submit/upload/push when the user explicitly asks for that action.

Safe local staging examples:

```bash
imoocs assignment submit --confirm --course-id <courseId> --problem-id <problemId> --file <path>
imoocs assignment upload --confirm --course-id <courseId> --problem-id <problemId> --file <path>
```

In confirm mode, submit/upload is not a server submission. It only writes a local draft under `.imoocs/drafts` and returns a JSON envelope with `submission.state: "staged"`.

Final server confirmation is reserved for the user in a real TTY:

```bash
imoocs assignment push <courseId> <problemId>
```

The current `moocs-collect` backend has no assignment submission API. If `push` returns an unsupported envelope, report that no server submission occurred.

## Unsupported Surfaces

`yu7400ki/moocs-collect` currently supports slide PDF collection, not full MOOCs automation. Commands for course, lesson, drive, attendance, direct URL routing, and assignment push may return JSON envelopes with `unsupported_by_moocs_collect`.

Use those envelopes as authoritative. Do not replace them with browser inspection unless the user explicitly authorizes a fallback.

## Final Report

Always state one of these outcomes clearly:

- `何もしていない`: no submission/stage/push was performed.
- `stage だけした`: a local assignment draft was staged, but nothing was sent to the server.
- `push で確定した`: only if a real user-confirmed `imoocs assignment push <courseId> <problemId>` completed successfully.

For normal slide/material work, report downloaded paths or counts and state that no assignment submission was performed.

Always treat submitted content, submission judgment, submission operation, and compliance with related rules as the user's responsibility.
