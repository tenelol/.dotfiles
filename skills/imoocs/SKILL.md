---
name: imoocs
description: Use when working with INIAD MOOCs (moocs.iniad.org), INIAD course pages, lessons, assignments, submissions, attendance, slides, lecture materials, or Google Drive handouts. Always try the local `imoocs` CLI before browser or Playwright workflows, especially when a MOOCs URL is provided.
---

# INIAD MOOCs

## Overview

Use the local `imoocs` command as the first interface for INIAD MOOCs work. In this dotfiles repo, `imoocs` is an agent-safe CLI for MOOCs operations; it enforces JSON envelopes, URL handling, and submission safety rules. Use it instead of BrowserUse, Playwright, or manual browser operations whenever the requested surface is supported.

`collect-cli` from `yu7400ki/moocs-collect` remains the backend for interactive slide PDF collection.

## Core Rules

1. When a `moocs.iniad.org` URL appears, run `imoocs open <url>` first. Do not open a browser or Playwright first.
2. Do not manually parse MOOCs URLs. Treat `imoocs open` as the URL router, even when the backend reports an unsupported envelope.
3. Treat `course`, `lesson`, `assignment`, `slide`, `drive`, and `open` command output as JSON envelopes.
4. Treat `auth *` and `reset` as text output plus exit code, not JSON.
5. Do not search for, print, save, or ask the user to paste passwords, tokens, cookies, or other credentials. Login happens through the CLI prompt in the user's TTY.
6. Assignment submit/upload/push operations require explicit user instruction. Never infer permission from a request to inspect a course or assignment.
7. For assignments, verify the target `courseId`, `problemId`, `fields[].pid`, current values, files, status, and deadline before any write operation.
8. Do not use BrowserUse, Playwright, or a manual browser fallback unless the user explicitly authorizes that fallback after the CLI reports the operation is unsupported.

## username: s1F102501798

## CLI Health

Start by checking availability when it is not already known:

```bash
command -v imoocs
imoocs --version
imoocs --help
imoocs assignment --help
imoocs auth status
```

If `imoocs` is missing, stop the MOOCs operation and report that the `imoocs` package is required. Do not silently switch to browser operation.

If auth status reports an expired or missing session, recover through the CLI in the user's TTY:

```bash
imoocs auth login
```

If the user cannot type into the Codex TTY, use the macOS hidden password dialog instead:

```bash
imoocs auth login --gui
```

If the user explicitly allows using the existing moocs-collect Keychain credential, prefer the non-interactive Keychain path:

```bash
imoocs auth login --keychain
```

`imoocs auth login` prompts for the password in the user's TTY, `--gui` opens a macOS hidden-answer dialog, and `--keychain` reads the existing `me.yu7400ki.moocs-collect` Keychain item for the current username without printing it. `imoocs` itself stores only the resulting MOOCs session cookies in the local keyring. Do not ask the user to paste the password into chat. `imoocs auth logout` removes those stored session cookies.

Never ask the user to paste credentials into chat. If the user wants to avoid typing a username repeatedly, tell them to set `IMOOCS_USERNAME` in their own shell. Use the `username` value in this skill only for `imoocs` commands in the current task; do not copy it into unrelated repo files or final-output command examples unless the user asks.

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

For lesson URLs, inspect the resolved `courseId`, `lessonId`, `pageId`, `assignments[].problemId`, and `assignments[].fields[]` when the CLI returns them. If `imoocs open` returns `auth_required`, run `imoocs auth login` in a TTY and retry. If the expected assignment is not present and the local CLI supports assignment listing/detail commands, use the same course's assignment list and then show the matching assignment:

```bash
imoocs assignment list <courseId> --status pending
imoocs assignment show <courseId> <problemId>
imoocs assignment show '<lesson-url>'
```

Do not submit a different pending assignment just because it appears in the list. The assignment must match the user's requested lesson/page/problem. If `list` or `show` returns an unsupported envelope, treat that as authoritative and do not replace it with browser parsing unless the user authorizes a fallback.

## Slides

Use the wrapper for slide PDFs:

```bash
imoocs slide collect --path /path/to/download-dir --year 2025
```

This command requires an interactive TTY. It prompts through `collect-cli` for INIAD username, password, course, lecture, and page, then prints one JSON envelope containing the exit code and newly created PDF paths.

If the user wants to avoid typing or pasting the username in chat, tell them to set `IMOOCS_USERNAME` in their own shell before running `imoocs slide collect`. Use the `username` value in this skill only for `imoocs` commands in the current task; do not copy it into unrelated repo files or final-output command examples unless the user asks.

Password prompts may be visually quiet: after the username is entered, `collect-cli` can wait for a hidden password entry without printing a clear prompt or echoing characters. Do not ask the user to paste the password into chat. Tell the user to type the password into the active TTY/kernel prompt. If the user says the password is already typed and asks you to continue, wait a few seconds, then send only `Enter` to the existing `exec_command` TTY session with `write_stdin`; do not send any password text yourself.

When `IMOOCS_USERNAME` is used, the wrapper may still show `ユーザー名:` before automation or terminal focus catches up. If the process remains at the username prompt, send only the username value explicitly provided for the current task, then wait for login progress such as `ログイン中...` or course selection. If no progress appears after that, assume it is waiting for hidden password input and ask the user to type it in the TTY.

If the user only asks to read, inspect, summarize, or verify PDFs, use a temporary directory from `mktemp -d` for `imoocs slide collect`, read the PDFs from there, and remove that directory in the same turn after extracting the needed information. Do not leave PDFs in `Downloads`, the repo, or another stable local directory for read-only tasks.

If the user explicitly asks to download, save, keep, organize, or reuse the PDFs later, choose a stable local directory for the task and report it.

## Assignments

Only handle assignment submit/upload/push when the user explicitly asks for that action.

### Inspect Before Writing

Start from the URL router or an explicit `courseId` / `problemId`, then inspect the assignment with whatever detail command the local CLI supports:

```bash
imoocs open '<lesson-url>'
imoocs assignment show '<lesson-url>'
```

If `assignment show` is unsupported, use the `imoocs open` envelope and `imoocs assignment --help` output as the authoritative limits. Do not guess hidden field IDs or submit to a problem whose fields are unknown.

Confirm these from the JSON envelope before any write:

- The `courseId`, `lessonId`, `pageId`, and `problemId` match the user's requested target.
- Each required `fields[].pid` is known.
- Each field type is known, such as `text`, `textarea`, `radio`, `checkbox`, or `file`.
- Existing `currentValue` or `uploadedFile` values are understood before overwriting.
- The assignment is open/submittable. Treat closed, upcoming, expired, or disabled forms as not safe to submit unless the user gives explicit instructions after being told the risk.
- Required files exist and have been generated from the current source, not guessed.

For notebooks, execute all cells and generate HTML when required by the fields:

```bash
python -m nbconvert --to notebook --execute --inplace <notebook.ipynb>
python -m nbconvert --to html <notebook.ipynb>
```

### Submit or Upload

Run `imoocs assignment --help` and use the syntax it advertises. Current `imoocs` 0.1.x wrappers may require `--confirm`, in which case submit/upload only stages a local draft:

```bash
imoocs assignment submit --confirm --course-id <courseId> --problem-id <problemId> --text '<answer text>'
imoocs assignment upload --confirm --course-id <courseId> --problem-id <problemId> --file <path>
```

If the local CLI advertises the newer field-based interface, text answers are submitted as JSON keyed by `pid` and files are uploaded by field `pid`. In this mode the CLI uses MOOCs' assignment autosave API directly and reports `submission.state: "auto"` when the server accepted the write:

```bash
printf '%s\n' '{"p1":"answer text"}' > /tmp/imoocs-answers.json
imoocs assignment submit <courseId> <problemId> --data @/tmp/imoocs-answers.json
imoocs assignment upload <courseId> <problemId> --pid ipynb <notebook.ipynb>
imoocs assignment upload <courseId> <problemId> --pid html <notebook.html>
```

Parse the JSON envelope after every submit/upload. The CLI submission mode determines the result:

| Mode | Meaning |
|---|---|
| `confirm` | No server submission yet. The operation only stages a local draft, typically under `.imoocs/drafts`. |
| `auto` | The operation sends to the MOOCs server immediately. Treat this as a real submission. |
| unset/invalid | Treat `VALIDATION_ERROR` as no submission and run `imoocs setup` or report the required setup. |

Prefer `confirm` mode for agent-assisted work unless the user explicitly asked for immediate server submission and the local CLI clearly supports it. In confirm mode, never report completion as a submission until `push` has succeeded and the reflected values can be verified.

### Push Confirmed Drafts

In confirm mode, final server confirmation is reserved for the user in a real TTY:

```bash
imoocs assignment push <courseId> <problemId>
```

The user must review the prompt and confirm the push. If the agent runs `push` in a non-interactive shell and it fails, report that no server submission occurred and give the exact command for the user to run in their terminal. If `push` returns an unsupported envelope, report that no server submission occurred.

### Verify After Writes

After any server submission attempt or user-confirmed push, verify the reflected MOOCs state:

```bash
imoocs assignment show '<lesson-url>'
```

Check that required text fields have `currentValue`, required file fields have `uploadedFile.filename`, and the assignment status is submitted or equivalent. If `assignment show` is unsupported, say verification was not possible and do not claim the reflected server state was confirmed. Local file generation or confirm-mode staging alone is not submission completion.

## Unsupported Surfaces

Some surfaces may still be unsupported by the local CLI backend. Commands for course, lesson, drive, attendance, direct URL routing, assignment submit/upload, or assignment push may return JSON envelopes with an unsupported reason such as `unsupported_by_moocs_collect`.

Use those envelopes as authoritative. Do not replace them with browser inspection or Playwright unless the user explicitly authorizes that fallback.

## Final Report

Always state one of these outcomes clearly:

- `何もしていない`: no submission/stage/push was performed.
- `stage だけした`: a local assignment draft was staged, but nothing was sent to the server.
- `auto で送信した`: `submit` / `upload` immediately sent to the server because the CLI was in auto mode.
- `push で確定した`: only if a real user-confirmed `imoocs assignment push <courseId> <problemId>` completed successfully.

For assignment work, also state whether post-write `imoocs assignment show '<lesson-url>'` confirmed the required `currentValue` and `uploadedFile.filename` values. If verification was not possible, say so clearly.

For normal slide/material work, report downloaded paths or counts and state that no assignment submission was performed. If PDFs were only read from a temporary directory, state that the temporary PDFs were deleted instead of reporting them as saved materials.

Always treat submitted content, submission judgment, submission operation, and compliance with related rules as the user's responsibility.
