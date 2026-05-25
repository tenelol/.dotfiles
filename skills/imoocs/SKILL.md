---
name: imoocs
description: Use when working with INIAD MOOCs (moocs.iniad.org), INIAD course pages, lessons, assignments, submissions, attendance, slides, lecture materials, or Google Drive handouts through the local `imoocs` CLI. Trigger on INIAD, MOOCs, 課題, 提出, 出席, スライド, 授業資料, course, lesson, assignment, slide, drive, or any moocs.iniad.org URL; use CLI workflows instead of browser or Playwright workflows.
---

# INIAD MOOCs CLI

## Overview

Use the unofficial Rust CLI `imoocs` as the first entrypoint for INIAD MOOCs work. Prefer structured CLI output over web-browser inspection.

## Core Rules

1. When a `moocs.iniad.org` URL appears, run `imoocs open <url>` first.
2. Do not manually parse MOOCs URLs. Let `imoocs open` route them.
3. Do not use a browser, Playwright, or page scraping for MOOCs data unless the user explicitly asks to bypass `imoocs` or `imoocs` is unavailable and the user approves a fallback.
4. Treat `course`, `lesson`, `assignment`, `slide`, `drive`, and `open` output as a JSON envelope.
5. Treat `auth *` and `reset` as text output plus exit code.
6. Do not search for, print, save, or ask the user to paste passwords, tokens, cookies, or other credentials. Login/setup should happen in the user's TTY.

## CLI Health

Start by checking availability when it is not already known:

```bash
command -v imoocs
imoocs doctor
```

If `imoocs` is missing or `doctor` reports missing auth/config, stop the MOOCs operation and report the exact missing prerequisite. Do not switch to browser operation silently.

Known install paths from upstream documentation:

```bash
npm install -g @rarandeyo/iniad-moocs-cli@0.2.0
cargo install --git https://github.com/rarandeyo/iniad-moocs-cli imoocs-cli
```

Only run install/setup/auth commands when the user asks for environment setup. Verify that the upstream package or release is reachable first; if it returns 404 or requires unavailable repository access, report that instead of retrying. For authentication, prefer telling the user to run `imoocs setup` or `imoocs auth login` in a real terminal.

## Output Contract

For these commands, parse stdout as a stable JSON envelope:

```json
{ "success": true, "data": {} }
{ "success": false, "error": { "code": "...", "message": "...", "hint": "..." } }
```

Relevant command families:

```bash
imoocs course list
imoocs course show <courseId>
imoocs lesson show <courseId> <lessonId>
imoocs slide fetch <embedUrl>
imoocs assignment list <courseId>
imoocs assignment show <courseId> <problemId>
imoocs drive list
imoocs drive search <query>
imoocs drive fetch <id-or-url>
imoocs drive folders
imoocs open <url>
imoocs doctor
imoocs version
```

Use a JSON parser (`jq`, language JSON APIs, or equivalent) for decisions. If `success` is false, report `error.code`, `error.message`, and `error.hint` when present.

Exit code meanings: `0` success, `1` API, `2` Auth, `3` Validation, `4` NotFound, `5` Internal, `6` Network, `7` NetworkRestricted, `8` NonPublic.

## Auth And Reset

For these commands, judge by text output and exit code:

```bash
imoocs setup
imoocs auth login
imoocs auth login-google
imoocs auth logout
imoocs auth status
imoocs auth export
imoocs reset --scope auth|config|cache|drafts|all
```

`reset` can delete local auth/config/cache/drafts. Use `--dry-run` first when inspecting impact, and do not run destructive reset scopes unless the user explicitly asks.

## Read-Only Workflows

For course, lesson, slide, assignment inspection, and Drive material retrieval:

1. Prefer `imoocs open <url>` when given a URL.
2. Otherwise use the narrowest explicit command (`course list`, `lesson show`, `assignment show`, `drive search`, `drive fetch`).
3. Save fetched slides/materials only when the user requests files or the downstream task needs local artifacts.
4. Report local output paths when files are fetched.

Do not infer course IDs, lesson IDs, problem IDs, or Drive IDs by hand from URL strings. Use CLI output.

## Assignment Submission Rules

Viewing assignment metadata is allowed. Submitting or staging answers is only allowed when the user explicitly asks to submit, upload, or prepare a submission.

`assignment.confirm` controls side effects:

- `confirm`: `imoocs assignment submit` and `imoocs assignment upload` stage a local draft only. They do not send to the server. Final confirmation must be done by the user in TTY with:

```bash
imoocs assignment push <courseId> <problemId>
```

- `auto`: `submit` and `upload` may immediately send to the server. Treat this as high-risk and only proceed after explicit user instruction.
- unset: submission commands should fail validation; ask the user to configure with `imoocs setup`.

Do not run `imoocs assignment push` on behalf of the user. Give the exact command for the user to run in TTY.

Before staging or submitting files, verify that the requested file exists and matches the assignment target as far as the user-provided context allows. Do not invent answers or decide whether content is academically acceptable.

## Final Report

Always state one of these outcomes clearly:

- `何もしていない`: no submission/stage/push was performed.
- `stage だけした`: a local draft was staged; server submission is not confirmed.
- `push で確定した`: server-side confirmation was completed.

Also state that the submission content, decision to submit, submission operation, and compliance with applicable rules are the user's responsibility.
