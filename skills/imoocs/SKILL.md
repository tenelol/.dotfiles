---
name: imoocs
description: Use when working with INIAD MOOCs (moocs.iniad.org), INIAD course pages, lessons, assignments, submissions, attendance, slides, lecture materials, or Google Drive handouts. Always try the local `imoocs` CLI before browser or Playwright workflows, especially when a MOOCs URL is provided.
---

# INIAD MOOCs

## Overview

Use the local `imoocs` command as the first interface for INIAD MOOCs work. In this dotfiles repo, `imoocs` is an agent-safe CLI for MOOCs operations; it enforces JSON envelopes, URL handling, and submission safety rules. Use it instead of BrowserUse, Playwright, or manual browser operations whenever the requested surface is supported.

Slide PDF collection is implemented in the local `imoocs` CLI. It uses the stored `imoocs auth login` MOOCs and Google session cookies and does not require `collect-cli`.

## Core Rules

1. When a `moocs.iniad.org` URL appears, run `imoocs open <url>` first. Do not open a browser or Playwright first.
2. Do not manually parse MOOCs URLs. Treat `imoocs open` as the URL router, even when the backend reports an unsupported envelope.
3. Treat `course`, `lesson`, `assignment`, `slide`, `drive`, and `open` command output as JSON envelopes.
4. Treat `auth *` and `reset` as text output plus exit code, not JSON.
5. Do not search for, print, save, or ask the user to paste passwords, tokens, cookies, or other credentials. `imoocs auth login` stores resulting MOOCs cookies in the local keyring. `imoocs auth import-browser` may import an existing local browser Google session into the same CLI cookie jar, but must never print cookie values. Google session failure does not invalidate a saved MOOCs session for assignment operations. In Codex desktop sessions, when MOOCs auth recovery is needed, try the existing INIAD Keychain credential; this does not require additional user permission. Supported Keychain items are the moocs-collect service `me.yu7400ki.moocs-collect` and, as fallback for the same username, the INIAD 802.1X Wi-Fi service `com.apple.network.eap.user.item.wlan.ssid.iniad`. Keychain reads must use a short timeout; if Keychain auth is unavailable, missing, rejected, or blocked, stop the auth/material operation and report the Keychain blocker instead of automatically using GUI, TTY, browser, or any other password flow.
6. Assignment submit/upload/push operations require explicit user instruction. Never infer permission from a request to inspect a course or assignment.
7. For assignments, enumerate every `assignments[]` entry returned for the target page, then verify each entry's `courseId`, `problemId`, `fields[].pid`, `currentAnswers` / `currentAnswerDetails` keys, current values, files, status, and deadline before any write operation. Treat `data.problem` and `route.problemId` only as backward-compatible aliases for the first entry.
8. Before solving or submitting a lesson assignment, read the lesson's embedded slides, linked slide deck, handouts, PDFs, notebooks, and data files needed to understand the actual questions. Do not rely only on the assignment form body; MOOCs forms often contain only answer fields. If the slide/material content cannot be obtained through supported local/CLI/Keychain-backed paths, stop and report exactly which material is blocked instead of guessing.
9. Do not use BrowserUse, Playwright, or a manual browser fallback unless the user explicitly authorizes that fallback after the CLI reports the operation is unsupported.

## username: s1F102501798

## CLI Health

Start by checking availability when it is not already known:

```bash
command -v imoocs
imoocs --version
imoocs --help
imoocs assignment --help
imoocs auth status
imoocs auth import-browser --help
```

If `imoocs` is missing, stop the MOOCs operation and report that the `imoocs` package is required. Do not silently switch to browser operation.

If auth status reports an expired or missing session in a Codex desktop session, recover with the existing INIAD Keychain credential every time. This path is allowed by default and does not require asking the user for permission. The CLI first checks `me.yu7400ki.moocs-collect`, then falls back to `com.apple.network.eap.user.item.wlan.ssid.iniad` for the same username:

```bash
imoocs auth login --keychain
```

When running this from Codex and `IMOOCS_USERNAME` is not already set, use the `username` value in this skill as `IMOOCS_USERNAME` for the current MOOCs task only.

If Keychain auth reports that no password was found, credentials were rejected, additional verification is required, or the command appears blocked on macOS Keychain access for more than a short wait, stop the MOOCs auth/material operation and report that Keychain auth is blocked. Do not launch the macOS hidden password dialog unless the user explicitly asks for GUI password entry in the current turn:

```bash
imoocs auth login --gui
```

Use the plain TTY prompt only when the user explicitly asks to type in the terminal:

```bash
imoocs auth login
```

`imoocs auth login --gui` opens a macOS hidden-answer dialog, `imoocs auth login` prompts for the password in the user's TTY, and `--keychain` reads an existing supported INIAD Keychain item for the current username without printing it. `imoocs` stores resulting MOOCs cookies in the local keyring and exits without attempting Google Slides or Drive by default. Assignment `open`, `show`, `submit`, and `push` use the MOOCs session. For Google Slides and Google Drive, use `imoocs auth import-browser --browser auto` to import existing local browser Google cookies into the CLI cookie jar; this is a CLI auth recovery path, not browser material inspection. Chrome profile discovery tries INIAD-looking profiles first; if auto-detection picks the wrong profile, use `imoocs auth import-browser --browser chrome --profile 'Profile 2'` or set `IMOOCS_BROWSER_PROFILE`. Normal `open`, `slide collect`, and `assignment` commands try to refresh an expired MOOCs session from the stored SSO cookies before returning `auth_required`; if that refresh fails, run `imoocs auth login` once again. Do not ask the user to paste the password into chat. Do not use GUI or TTY password flows as an automatic fallback from Keychain failure. `imoocs auth logout` removes those stored session cookies.

Never ask the user to paste credentials into chat. If the user wants to avoid typing a username repeatedly, tell them to set `IMOOCS_USERNAME` in their own shell. Use the `username` value in this skill only for `imoocs` commands in the current task; do not copy it into unrelated repo files or final-output command examples unless the user asks.

## URLs

```bash
imoocs open 'https://moocs.iniad.org/...'
```

Parse the JSON envelope. If `ok` is false, report the unsupported operation and use the envelope's `data.next` hints where relevant. Do not parse the URL by hand.

For lesson URLs, inspect the resolved `courseId`, `lessonId`, `pageId`, `assignmentCount`, every `assignments[].problemId`, and every `assignments[].fields[]` when the CLI returns them. Do not assume that one lesson page contains one assignment or stop after `data.problem`; the array is authoritative and may contain any number of entries. If `imoocs open` returns `auth_required`, run `imoocs auth login --keychain` in Codex desktop sessions, then retry only if Keychain auth succeeds. If Keychain auth fails or blocks, stop and report the Keychain blocker; do not fall back to GUI/TTY/browser unless the user explicitly authorizes that fallback in the current turn. If the expected assignment is not present and the local CLI supports assignment listing/detail commands, use the same course's assignment list and then show the matching assignment:

```bash
imoocs assignment list <courseId> --status pending
imoocs assignment show <courseId> <problemId>
imoocs assignment show '<lesson-url>'
```

Do not submit a different pending assignment just because it appears in the list. The assignment must match the user's requested lesson/page/problem. If `list` or `show` returns an unsupported envelope, treat that as authoritative and do not replace it with browser parsing unless the user authorizes a fallback.

## Slides

Use the native slide PDF collector:

```bash
imoocs slide collect --path /path/to/download-dir --year 2025
```

This command uses stored `imoocs auth login` MOOCs and Google session cookies. It never prompts for a password and never calls `collect-cli`. If no valid MOOCs session is stored, it returns an `auth_required` JSON envelope with `data.authScope: "moocs"`; recover with `imoocs auth login --keychain` in Codex desktop sessions, then retry only if auth succeeds. If it returns `data.authScope: "google_slides"` or `data.cookieStore: "google_expired"`, do not retry Keychain or `imoocs auth login` automatically because the MOOCs session is already usable and the blocker is Google Docs access for the embedded slide deck. Instead, run `imoocs auth import-browser --browser auto`, then retry `slide collect`; newer `slide collect` may attempt this import automatically once before failing.

In an interactive TTY, missing `--course`, `--lecture`, or `--page` selectors are prompted as numbered menus. In non-interactive shells, pass selectors or explicit `--all`:

```bash
imoocs slide collect --path /path/to/download-dir --year 2025 --course COS101 --lecture all --page all
imoocs slide collect --path /path/to/download-dir --year 2025 --all
```

Selectors accept ids/slugs, names, 1-based indexes, or `all`; exact ids such as lessonId `13` or pageId `03` are preferred over menu indexes. Avoid `--all` for read-only inspection unless the user explicitly asks to collect broad materials.

If Google Slides PDF export fails after browser-cookie import, or no slide iframe is found, treat that JSON envelope as authoritative. Do not fall back to BrowserUse, Playwright, manual URL parsing, manual slide inspection, or `collect-cli` unless the user explicitly authorizes a fallback in the current turn.

If the user only asks to read, inspect, summarize, or verify PDFs, use a temporary directory from `mktemp -d` for `imoocs slide collect`, read the PDFs from there, and remove that directory in the same turn after extracting the needed information. Do not leave PDFs in `Downloads`, the repo, or another stable local directory for read-only tasks.

If the user explicitly asks to download, save, keep, organize, or reuse the PDFs later, choose a stable local directory for the task and report it.

## Google Drive

Use the native Drive collector for course handouts and sample data stored outside MOOCs pages:

```bash
imoocs drive ls
imoocs drive ls --match 'ソフトウェア・エンジニアリング'
imoocs drive collect --path /path/to/download-dir --match 'ソフトウェア・エンジニアリング'
imoocs drive collect --path /path/to/download-dir --parent '<drive-folder-url-or-id>' --recursive
```

The default Drive parent folder is:

```text
https://drive.google.com/drive/u/0/folders/1MDPeeFHJDmqgQeuJQOHPpWPLDyhT3ZSU
```

Drive commands use stored Google cookies from the same CLI cookie jar as slide collection. If Drive returns `auth_required` with `data.authScope: "google_drive"` or `data.cookieStore: "google_expired"`, run `imoocs auth import-browser --browser auto`, then retry the Drive command. If Chrome has multiple profiles and auto-detection fails, retry with `--browser chrome --profile 'Profile 2'` or the profile directory/name shown by Chrome. Do not run `imoocs auth login`, Keychain auth, GUI auth, BrowserUse, Playwright, or manual browser inspection for Drive-only failures unless the user explicitly authorizes that fallback in the current turn.

`imoocs drive collect --match <text>` treats matching direct child folders of the default parent as the selected course folder and collects their contents recursively. Without `--match` or `--recursive`, folders are listed or skipped rather than broadly downloading every course folder.

## Assignments

Only handle assignment submit/upload/push when the user explicitly asks for that action. A request such as "submit this", "finish this", "complete it", or "提出まで終わらせて" is explicit permission to solve, save, upload, push, and verify the matching assignment.

When that request targets a lesson/page URL and does not explicitly limit the scope, complete every entry returned in `assignments[]`, regardless of the number of entries. Process each `problemId` independently: inspect all fields and answer details, solve and upload its required artifacts, run `push` for that problem, then reopen the original URL and verify that same array entry. Never use the first entry's successful push as evidence that later entries were completed. If an entry cannot be completed, continue safely with independent entries when possible and report the exact blocked `problemId` and field.

When the user asks to finish or submit an assignment without limiting the scope, complete every visible answer field, not only required fields. Treat optional, challenge, bonus, and file-upload fields as in scope unless the user explicitly asks for required-only work, the field is impossible/unsafe to complete, or the field's instructions clearly require unavailable personal input. If any visible field is skipped, state the exact field and reason before the final report.

Some INIAD MOOCs forms expose select/dropdown or radio-like answers only in `currentAnswers` / `currentAnswerDetails`, while omitting those pids from `fields[]`. Treat placeholder values such as `---`, empty strings, or option-looking current answers for pids not listed in `fields[]` as in-scope visible fields when the page text shows a selector or choice. Infer the pid from the `currentAnswers` key, solve it from the assignment instructions, submit it in the same JSON payload, and verify it after submission.

### Inspect Before Writing

Start from the URL router or an explicit `courseId` / `problemId`, then inspect the assignment with whatever detail command the local CLI supports:

```bash
imoocs open '<lesson-url>'
imoocs assignment show '<lesson-url>'
```

If `assignment show` is unsupported, use the `imoocs open` envelope and `imoocs assignment --help` output as the authoritative limits. Do not guess hidden field IDs or submit to a problem whose fields are unknown.

Confirm these from the JSON envelope before any write:

- The `courseId`, `lessonId`, `pageId`, and `problemId` match the user's requested target.
- Every visible `fields[].pid` is known, including optional/challenge/bonus fields when the user asked to finish or submit the whole assignment.
- Every non-system `currentAnswers` / `currentAnswerDetails` key is reviewed, even if it is absent from `fields[]`. Pay special attention to `---` placeholder values: they often represent dropdown/select fields.
- Each field type is known, such as `text`, `textarea`, `radio`, `checkbox`, or `file`.
- Existing `currentValue` or `uploadedFile` values are understood before overwriting.
- The assignment is open/submittable. Treat closed, upcoming, expired, or disabled forms as not safe to submit unless the user gives explicit instructions after being told the risk.
- Required files and in-scope optional/challenge upload files exist and have been generated from the current source, not guessed.

Read the assignment page and any linked exercise PDFs, slides, or handouts needed to understand all visible fields before deciding a field can be left blank.

For slide-backed form assignments, verify the actual question text from the slide deck or downloaded slide PDF before writing answers. If the page has an embedded Google Slides iframe, use the slide deck/material as primary question evidence. The form labels alone are not sufficient evidence for numeric/statistical answers.

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

If the local CLI advertises the newer field-based interface, text answers are saved as JSON keyed by `pid` and files are uploaded by field `pid`. In this mode the CLI uses MOOCs' assignment autosave API directly and reports `submission.state: "auto"` when the server accepted the write. This is server-side answer storage, not final confirmation by the page's green Submit button:

```bash
printf '%s\n' '{"p1":"answer text"}' > /tmp/imoocs-answers.json
imoocs assignment submit <courseId> <problemId> --data @/tmp/imoocs-answers.json
imoocs assignment upload <courseId> <problemId> --pid ipynb <notebook.ipynb>
imoocs assignment upload <courseId> <problemId> --pid html <notebook.html>
```

Include solved dropdown/select pids discovered only from `currentAnswers` in the same JSON payload, for example `{"p5":"option text","p6":"other option"}`. If the server accepts a pid that was absent from `fields[]`, treat the returned `currentAnswers` value as the authoritative confirmation.

Parse the JSON envelope after every submit/upload. The CLI submission mode determines the result:

| Mode | Meaning |
|---|---|
| `confirm` | No server submission yet. The operation only stages a local draft, typically under `.imoocs/drafts`. |
| `auto` | The operation sends/saves answers to the MOOCs server immediately, but it may still require `push` for final confirmation. |
| unset/invalid | Treat `VALIDATION_ERROR` as no submission and run `imoocs setup` or report the required setup. |

Prefer `confirm` mode for agent-assisted work unless the user explicitly asked for immediate server submission and the local CLI clearly supports it. Never report final completion until `push` has succeeded and the reflected values can be verified.

### Push Final Confirmation

After saving all intended answers, use `push` to perform the final submit-button confirmation through the CLI:

```bash
imoocs assignment push <courseId> <problemId>
```

Parse the JSON envelope. Treat `submission.state: "push"` and `data.serverSubmitted: true` as final confirmation. On the current MOOCs frontend, the green submit button verifies `/answers` autosave and leaves `data.assignmentStatus` as `open`; this is normal and should not be treated as a failed push. If `push` returns `auth_required`, `push_failed`, `not_submittable`, or any other non-ok envelope, report that no final submit-button confirmation occurred.

### Verify After Writes

After any server submission attempt or user-confirmed push, verify the reflected MOOCs state:

```bash
imoocs assignment show '<lesson-url>'
```

Match every in-scope `assignments[]` entry by `problemId`. For each entry, check that all intended text fields, including optional/challenge fields, have `currentValue`; all dropdown/select pids discovered from `currentAnswers` / `currentAnswerDetails` have the expected data value instead of `---`; and all intended file fields have `uploadedFile.filename`. Confirm that the post-write array still contains every originally discovered `problemId`; do not verify only the first compatibility alias. For current MOOCs pages, `status: open` can remain after the green submit-button confirmation, so rely on reflected answer/file values plus that problem's successful `push` rather than requiring a submitted status. If `assignment show` is unsupported, say verification was not possible and do not claim the reflected server state was confirmed. Local file generation or confirm-mode staging alone is not submission completion.

## Unsupported Surfaces

Some surfaces may still be unsupported by the local CLI backend. Commands for course, lesson, attendance, direct URL routing, assignment submit/upload, or assignment push may return JSON envelopes with an unsupported reason such as `unsupported_by_imoocs`.

Use those envelopes as authoritative. Do not replace them with browser inspection or Playwright unless the user explicitly authorizes that fallback.

## Final Report

Always state one of these outcomes clearly:

- `何もしていない`: no submission/stage/push was performed.
- `stage だけした`: a local assignment draft was staged, but nothing was sent to the server.
- `auto で保存した`: `submit` / `upload` immediately saved answers/files to the server because the CLI was in auto mode, but final submit-button confirmation did not happen.
- `push で確定した`: only if `imoocs assignment push <courseId> <problemId>` completed successfully with `submission.state: "push"` and `data.serverSubmitted: true`.

For assignment work, also state whether post-write `imoocs assignment show '<lesson-url>'` confirmed the required and in-scope optional/challenge `currentValue` and `uploadedFile.filename` values. If verification was not possible, say so clearly. If a finish/submit request left any visible field blank, list the skipped field and reason.

For normal slide/material work, report downloaded paths or counts and state that no assignment submission was performed. If PDFs were only read from a temporary directory, state that the temporary PDFs were deleted instead of reporting them as saved materials.

For every completed MOOCs task, include a clickable Markdown link to the exact target course, lesson, or assignment URL in the final report so the user can verify the result immediately. Prefer the URL supplied by the user; otherwise use the URL resolved by `imoocs open`.

Always treat submitted content, submission judgment, submission operation, and compliance with related rules as the user's responsibility.
